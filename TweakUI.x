#import "UIKitPrivate.h"
#import <objc/runtime.h>

static BOOL trollPadEnabled = YES, enableiPadKeyboard = YES, forcePadKBIdiom = YES, showShortcutButtonsOnKeyboard;
static BOOL keyboardHooksInitialized;

%group TPiPadKeyboardHooks
// Unlock iPadOS keyboard
UIUserInterfaceIdiom UIKeyboardGetSafeDeviceIdiom();
%hookf(UIUserInterfaceIdiom, UIKeyboardGetSafeDeviceIdiom) {
    if (!enableiPadKeyboard) {
        return %orig;
    }
    return forcePadKBIdiom ? UIUserInterfaceIdiomPad : %orig;
}

// Allow UIHoverGestureRecognizer and pointer interaction on iPhone
%hook UIPointerInteraction
- (void)_updateInteractionIsEnabled {
    if (!enableiPadKeyboard) {
        %orig;
        return;
    }

    static Ivar observingPresentationNotificationIvar;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        observingPresentationNotificationIvar = class_getInstanceVariable(
            UIPointerInteraction.class,
            "_observingPresentationNotification"
        );
    });
    if (!observingPresentationNotificationIvar) {
        %orig;
        return;
    }

    UIView *view = self.view;
    BOOL enabled = self.enabled; // && view.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad
    for(id<_UIPointerInteractionDriver> driver in self.drivers) {
        driver.view = enabled ? view : nil;
    }
    // to keep it fast, ivar offset is cached for later direct access
    ptrdiff_t ivarOff = ivar_getOffset(observingPresentationNotificationIvar);

    BOOL *observingPresentationNotification = (BOOL *)((uint64_t)(__bridge void *)self + ivarOff);
    if(!enabled && *observingPresentationNotification) {
        [NSNotificationCenter.defaultCenter removeObserver:self name:UIPresentationControllerPresentationTransitionWillBeginNotification object:nil];
        *observingPresentationNotification = NO;
    }
}
%end

// Fix bottom padding
%hook UIKeyboardImpl
+ (UIEdgeInsets)deviceSpecificPaddingForInterfaceOrientation:(NSUInteger)arg1 inputMode:(id)arg2 {
    if (!enableiPadKeyboard) {
        return %orig;
    }
    forcePadKBIdiom = NO;
    UIEdgeInsets result = %orig;
    forcePadKBIdiom = YES;
    return result;
}
%end

// Fix bottom padding when floating
%hook UIKeyboardDockView
- (CGRect)bounds {
    CGRect bounds = %orig;
    if (!enableiPadKeyboard) {
        return bounds;
    }
    if (!UIDevice._hasHomeButton && UIKeyboardImpl.isFloating) {
        bounds.origin.y = -25;
    } else {
        bounds.origin.y = 0;
    }
    return bounds;
}
%end

%hook UISystemInputAssistantViewController
// Fix predictive bar not occupying entire area
- (CGFloat)_centerViewWidthForTraitCollection:(id)tc interfaceOrientation:(UIInterfaceOrientation)orientation {
    if (!enableiPadKeyboard) {
        return %orig;
    }
    forcePadKBIdiom = NO;
    NSInteger result = %orig;
    forcePadKBIdiom = YES;
    return result;
}

// Show assistant buttons when enabled
- (void)setInputAssistantButtonItemsForResponder:(id)item {
    if (!enableiPadKeyboard) {
        %orig;
        return;
    }
    forcePadKBIdiom = showShortcutButtonsOnKeyboard;
    %orig;
    forcePadKBIdiom = YES;
}
%end

%hook UIInputWindowControllerHosting
- (UIEdgeInsets)_inputViewPadding {
    UIEdgeInsets result = %orig;
    if (!enableiPadKeyboard) {
        return result;
    }
    if (!UIDevice._hasHomeButton && UIKeyboardImpl.isFloating) {
        result.bottom -= 25;
    }
    return result;
}
%end
%end

static void loadPrefs() {
    CFStringRef appID = CFSTR("com.kdt.trollpad");
    Boolean keyExists = false;

    CFPreferencesAppSynchronize(appID);
    trollPadEnabled = CFPreferencesGetAppBooleanValue(CFSTR("TPTrollPadEnabled"), appID, &keyExists);
    if (!keyExists) {
        trollPadEnabled = YES;
    }

    keyExists = false;
    enableiPadKeyboard = CFPreferencesGetAppBooleanValue(CFSTR("TPEnableiPadKeyboard"), appID, &keyExists);
    if (!keyExists) {
        enableiPadKeyboard = YES;
    }
    enableiPadKeyboard = trollPadEnabled && enableiPadKeyboard;
    showShortcutButtonsOnKeyboard = enableiPadKeyboard &&
        CFPreferencesGetAppBooleanValue(CFSTR("TPShowShortcutButtonsOnKeyboard"), appID, NULL);
}

static void initializeKeyboardHooksIfNeeded() {
    if (!enableiPadKeyboard || keyboardHooksInitialized) {
        return;
    }

    %init(TPiPadKeyboardHooks);
    keyboardHooksInitialized = YES;
}

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadPrefs();
    initializeKeyboardHooksIfNeeded();
}

%ctor {
    loadPrefs();
    initializeKeyboardHooksIfNeeded();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, prefsChanged, CFSTR("com.kdt.trollpad/saved"), NULL, CFNotificationSuspensionBehaviorCoalesce);
}
