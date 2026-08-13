#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#include <dlfcn.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <stdbool.h>
#include <string.h>

static BOOL (*TPOriginalSfIsiPad)(id, SEL);
static void (*TPOriginalMultitaskingViewWillAppear)(id, SEL, BOOL);
static void (*TPOriginalMultitaskingViewDidDisappear)(id, SEL, BOOL);
static BOOL TPNativeMultitaskingSettingsActive;

static void *TPFindImportedFunctionStub(const struct mach_header_64 *header,
    const char *symbolName) {
    if (!header || header->magic != MH_MAGIC_64) {
        return NULL;
    }

    const struct segment_command_64 *textSegment = NULL;
    const struct segment_command_64 *linkeditSegment = NULL;
    const struct section_64 *stubSection = NULL;
    const struct symtab_command *symtabCommand = NULL;
    const struct dysymtab_command *dysymtabCommand = NULL;
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    for (uint32_t index = 0; index < header->ncmds; index++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmd == LC_SEGMENT_64) {
            const struct segment_command_64 *segment =
                (const struct segment_command_64 *)command;
            if (strcmp(segment->segname, SEG_TEXT) == 0) {
                textSegment = segment;
            } else if (strcmp(segment->segname, SEG_LINKEDIT) == 0) {
                linkeditSegment = segment;
            }

            const struct section_64 *section =
                (const struct section_64 *)(segment + 1);
            for (uint32_t sectionIndex = 0; sectionIndex < segment->nsects;
                 sectionIndex++, section++) {
                if (strcmp(section->sectname, "__auth_stubs") == 0 ||
                    strcmp(section->sectname, "__stubs") == 0) {
                    stubSection = section;
                }
            }
        } else if (command->cmd == LC_SYMTAB) {
            symtabCommand = (const struct symtab_command *)command;
        } else if (command->cmd == LC_DYSYMTAB) {
            dysymtabCommand = (const struct dysymtab_command *)command;
        }
        cursor += command->cmdsize;
    }

    if (!textSegment || !linkeditSegment || !stubSection || !symtabCommand ||
        !dysymtabCommand || stubSection->reserved2 == 0) {
        return NULL;
    }

    uintptr_t slide = (uintptr_t)header - (uintptr_t)textSegment->vmaddr;
    uintptr_t linkeditBase = slide + (uintptr_t)linkeditSegment->vmaddr -
        (uintptr_t)linkeditSegment->fileoff;
    const struct nlist_64 *symbolTable = (const struct nlist_64 *)(
        linkeditBase + symtabCommand->symoff);
    const char *stringTable = (const char *)(linkeditBase + symtabCommand->stroff);
    const uint32_t *indirectSymbolTable = (const uint32_t *)(
        linkeditBase + dysymtabCommand->indirectsymoff);
    uint64_t stubCount = stubSection->size / stubSection->reserved2;
    for (uint64_t index = 0; index < stubCount; index++) {
        uint32_t symbolIndex = indirectSymbolTable[stubSection->reserved1 + index];
        if (symbolIndex == INDIRECT_SYMBOL_ABS || symbolIndex == INDIRECT_SYMBOL_LOCAL ||
            (symbolIndex & (INDIRECT_SYMBOL_ABS | INDIRECT_SYMBOL_LOCAL)) ||
            symbolIndex >= symtabCommand->nsyms) {
            continue;
        }
        uint32_t stringOffset = symbolTable[symbolIndex].n_un.n_strx;
        if (stringOffset >= symtabCommand->strsize) {
            continue;
        }
        const char *name = stringTable + stringOffset;
        if (name && strcmp(name, symbolName) == 0) {
            return (void *)(slide + stubSection->addr +
                index * stubSection->reserved2);
        }
    }
    return NULL;
}

static bool TPDeviceSupportsMultitasking(id device) {
    return true;
}

static BOOL TPUIDeviceSfIsiPad(id self, SEL command) {
    BOOL originalValue = TPOriginalSfIsiPad ? TPOriginalSfIsiPad(self, command) :
        [self userInterfaceIdiom] == UIUserInterfaceIdiomPad;
    if (TPNativeMultitaskingSettingsActive) {
        return YES;
    }
    return originalValue;
}

static void TPMultitaskingViewWillAppear(id self, SEL command, BOOL animated) {
    TPNativeMultitaskingSettingsActive = YES;
    if (TPOriginalMultitaskingViewWillAppear) {
        TPOriginalMultitaskingViewWillAppear(self, command, animated);
    }
}

static void TPMultitaskingViewDidDisappear(id self, SEL command, BOOL animated) {
    if (TPOriginalMultitaskingViewDidDisappear) {
        TPOriginalMultitaskingViewDidDisappear(self, command, animated);
    }
    TPNativeMultitaskingSettingsActive = NO;
}

void TPPrepareNativeMultitaskingSettingsHooks(void) {
    if (@available(iOS 18.0, *)) {
        TPNativeMultitaskingSettingsActive = YES;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            Class controllerClass = NSClassFromString(@"MultitaskingAndGesturesSettings");
            Dl_info imageInfo = {0};
            BOOL installedCapabilityHooks = NO;
            if (controllerClass && dladdr((__bridge const void *)controllerClass, &imageInfo) &&
                imageInfo.dli_fbase) {
                const char *symbols[] = {
                    "_MobileGestalt_get_deviceSupportsEnhancedMultitasking",
                    "_MobileGestalt_get_deviceSupportsSingleDisplayEnhancedMultitasking",
                };
                for (NSUInteger index = 0; index < sizeof(symbols) / sizeof(symbols[0]); index++) {
                    void *stub = TPFindImportedFunctionStub(
                        (const struct mach_header_64 *)imageInfo.dli_fbase, symbols[index]);
                    if (stub) {
                        MSHookFunction(stub, (void *)&TPDeviceSupportsMultitasking, NULL);
                        installedCapabilityHooks = YES;
                    }
                }
            }

            if (!installedCapabilityHooks) {
                SEL selector = NSSelectorFromString(@"sf_isiPad");
                Class deviceClass = object_getClass(UIDevice.currentDevice);
                Method method = class_getInstanceMethod(deviceClass, selector);
                if (method) {
                    TPOriginalSfIsiPad = (BOOL (*)(id, SEL))method_setImplementation(
                        method, (IMP)TPUIDeviceSfIsiPad);
                } else {
                    NSLog(@"[TrollPadEx] No iOS 18 multitasking capability hook available");
                }
            }

            SEL appearSelector = @selector(viewWillAppear:);
            SEL disappearSelector = @selector(viewDidDisappear:);
            if (controllerClass && class_getInstanceMethod(controllerClass, appearSelector)) {
                MSHookMessageEx(controllerClass, appearSelector,
                    (IMP)TPMultitaskingViewWillAppear,
                    (IMP *)&TPOriginalMultitaskingViewWillAppear);
            }
            if (controllerClass && class_getInstanceMethod(controllerClass, disappearSelector)) {
                MSHookMessageEx(controllerClass, disappearSelector,
                    (IMP)TPMultitaskingViewDidDisappear,
                    (IMP *)&TPOriginalMultitaskingViewDidDisappear);
            }
        });
    }
}

%ctor {
    if (@available(iOS 17.0, *)) {
        if (@available(iOS 18.0, *)) {
            // Install iOS 18 capability hooks after the native settings bundle loads.
            return;
        }
        void *mobileGestalt = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (!mobileGestalt) {
            return;
        }

        const char *symbols[] = {
            "MobileGestalt_get_deviceSupportsEnhancedMultitasking",
            "MobileGestalt_get_deviceSupportsSingleDisplayEnhancedMultitasking",
        };
        for (NSUInteger index = 0; index < sizeof(symbols) / sizeof(symbols[0]); index++) {
            void *function = dlsym(mobileGestalt, symbols[index]);
            if (function) {
                MSHookFunction(function, (void *)&TPDeviceSupportsMultitasking, NULL);
            }
        }
    }
}
