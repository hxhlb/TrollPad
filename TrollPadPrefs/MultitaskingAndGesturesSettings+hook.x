#import <Foundation/Foundation.h>
#import <substrate.h>
#include <dlfcn.h>
#include <stdbool.h>

static bool TPDeviceSupportsMultitasking(void) {
    return true;
}

%ctor {
    if (@available(iOS 17.0, *)) {
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
