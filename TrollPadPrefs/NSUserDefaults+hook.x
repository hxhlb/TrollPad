#import <Foundation/Foundation.h>

static BOOL trollPadDefaultsHookEnabled;

static void loadTrollPadDefaultsHookEnabled(void) {
    Boolean keyExists = false;
    CFPreferencesAppSynchronize(CFSTR("com.kdt.trollpad"));
    trollPadDefaultsHookEnabled = CFPreferencesGetAppBooleanValue(
        CFSTR("TPTrollPadEnabled"), CFSTR("com.kdt.trollpad"), &keyExists);
    if (!keyExists) {
        trollPadDefaultsHookEnabled = YES;
    }
}

static void trollPadDefaultsPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    loadTrollPadDefaultsHookEnabled();
}

static BOOL shouldRedirectChamoisKey(NSString *key) {
    return trollPadDefaultsHookEnabled && [key hasPrefix:@"SBChamois"] &&
        ![key isEqualToString:@"SBChamoisWindowingEnabled"];
}

static NSString *redirectedChamoisKey(NSString *key) {
    return [@"TP" stringByAppendingString:key];
}

// Hook this to avoid real keys from being set
%hook NSUserDefaults
- (void)setBool:(BOOL)value forKey:(NSString *)key {
    if ([key isEqualToString:@"SBChamoisHideDock"]) {
        // Never ever set this to YES, as it is known to respring loop
        %orig(NO, key);
    } else if (shouldRedirectChamoisKey(key)) {
        %orig(value, redirectedChamoisKey(key));
    } else {
        %orig;
    }
}

- (BOOL)boolForKey:(NSString *)key {
    if (shouldRedirectChamoisKey(key)) {
        return %orig(redirectedChamoisKey(key));
    } else {
        return %orig;
    }
}

- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)key options:(NSKeyValueObservingOptions)options context:(void *)context {
    if (shouldRedirectChamoisKey(key)) {
        %orig(observer, redirectedChamoisKey(key), options, context);
    } else {
        %orig;
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)key context:(void *)context {
    if (shouldRedirectChamoisKey(key)) {
        %orig(observer, redirectedChamoisKey(key), context);
    } else {
        %orig;
    }
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)key {
    if (shouldRedirectChamoisKey(key)) {
        %orig(observer, redirectedChamoisKey(key));
    } else {
        %orig;
    }
}
%end

%ctor {
    loadTrollPadDefaultsHookEnabled();
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        trollPadDefaultsPrefsChanged, CFSTR("com.kdt.trollpad/saved"), NULL,
        CFNotificationSuspensionBehaviorCoalesce);
}
