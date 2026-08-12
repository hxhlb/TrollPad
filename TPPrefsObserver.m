#import "TPPrefsObserver.h"

static void TPPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    TPPrefsObserver *prefs = (__bridge TPPrefsObserver *)observer;
    [prefs observeValueForKeyPath:nil ofObject:nil change:nil context:nil];
}

@implementation TPPrefsObserver
- (instancetype)init {
    self = [super init];
    [self observeKey:@"TPAllowLandscapeHomeScreen"];
    [self observeKey:@"TPForceEnableMedusaForLandscapeOnlyApps"];
    [self observeKey:@"TPHideStageManagerResizeCorners"];
    [self observeKey:@"TPUseiPadAppSwitchingAnimation"];
    [self observeKey:@"TPIsFloatingDockSupported"];
    [self observeKey:@"TPScaleGridSwitcher"];
    [self observeKey:@"TPStageManagerSide"];
    [self observeKey:@"TPMirrorStageManagerSwitcher"];
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)self, TPPrefsChanged, CFSTR("com.kdt.trollpad/saved"),
        NULL, CFNotificationSuspensionBehaviorCoalesce);
    // Fetch keys
    [self observeValueForKeyPath:nil ofObject:nil change:nil context:nil];
    return self;
}

- (void)dealloc {
    CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(),
        (__bridge const void *)self, CFSTR("com.kdt.trollpad/saved"), NULL);
}

- (void)observeKey:(NSString *)key {
    [NSUserDefaults.standardUserDefaults addObserver:self
        forKeyPath:key
        options:NSKeyValueObservingOptionNew
        context:NULL];
}

 - (void)observeValueForKeyPath:(NSString *) 
keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    CFPreferencesAppSynchronize(CFSTR("com.apple.springboard"));
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults synchronize];
    self.allowLandscapeHomeScreen = [defaults boolForKey:@"TPAllowLandscapeHomeScreen"];
    self.forceEnableMedusaForLandscapeOnlyApps = [defaults boolForKey:@"TPForceEnableMedusaForLandscapeOnlyApps"];
    self.hideStageManagerResizeCorners = [defaults boolForKey:@"TPHideStageManagerResizeCorners"];
    self.useiPadAppSwitchingAnimation = [defaults boolForKey:@"TPUseiPadAppSwitchingAnimation"];
    self.isFloatingDockSupported = [defaults boolForKey:@"TPIsFloatingDockSupported"];
    self.scaleGridSwitcher = [defaults boolForKey:@"TPScaleGridSwitcher"];
    self.stageManagerSide = [defaults integerForKey:@"TPStageManagerSide"];
    id mirrorAppSwitcher = [defaults objectForKey:@"TPMirrorStageManagerSwitcher"];
    self.mirrorAppSwitcher = mirrorAppSwitcher ? [mirrorAppSwitcher boolValue] : YES;
}
@end
