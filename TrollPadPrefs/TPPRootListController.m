#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>
#import "TPPRootListController.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.kdt.trollpad.plist"

static NSString *const TPEnableiPadKeyboardKey = @"TPEnableiPadKeyboard";
static NSString *const TPEnableiPadKeyboardSpecifierID = @"ENABLE_IPAD_KEYBOARD";
static NSString *const TPShowShortcutButtonsSpecifierID = @"SHOW_SHORTCUT_BUTTONS";
static NSString *const TPStageManagerSideSpecifierID = @"STAGE_MANAGER_SIDE";
static NSString *const TPSystemMultitaskingSpecifierID = @"CONTINUOUS-EXPOSE";
static CFStringRef const TPSpringBoardPreferencesDomain = CFSTR("com.apple.springboard");

extern void TPPrepareNativeMultitaskingSettingsHooks(void);

static NSString *TPLocalized(NSString *key) {
    NSBundle *bundle = [NSBundle bundleForClass:TPPRootListController.class];
    return [bundle localizedStringForKey:key value:key table:@"Root"];
}

@interface TPPRootListController ()
@property(nonatomic, assign) BOOL didShowRespringRequiredAlert;
@end

static id TPCopySpringBoardPreference(NSString *key) {
    CFPreferencesAppSynchronize(TPSpringBoardPreferencesDomain);
    CFPropertyListRef value = CFPreferencesCopyAppValue((__bridge CFStringRef)key, TPSpringBoardPreferencesDomain);
    return CFBridgingRelease(value);
}

static BOOL TPReadSpringBoardBool(NSString *key, BOOL defaultValue) {
    id value = TPCopySpringBoardPreference(key);
    return value ? [value boolValue] : defaultValue;
}

static BOOL TPIsStageManagerEnabled(void) {
    return TPReadSpringBoardBool(@"SBChamoisWindowingEnabled", NO);
}

static void TPRestartStageManager(void) {
    NSUserDefaults *springBoardDefaults = [[NSUserDefaults alloc]
        initWithSuiteName:@"com.apple.springboard"];
    [springBoardDefaults setBool:NO forKey:@"SBChamoisWindowingEnabled"];
    [springBoardDefaults synchronize];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            [springBoardDefaults setBool:YES forKey:@"SBChamoisWindowingEnabled"];
            [springBoardDefaults synchronize];
        });
}

static Class TPLoadNativeMultitaskingController(void) {
    NSBundle *bundle = [NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/MultitaskingAndGesturesSettings.bundle"];
    if (![bundle load]) {
        return Nil;
    }
    TPPrepareNativeMultitaskingSettingsHooks();
    return bundle.principalClass;
}

static BOOL TPPreferenceRequiresRespring(NSString *key) {
    static NSSet<NSString *> *keys;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        keys = [NSSet setWithArray:@[
            @"SBExtendedDisplayOverrideSupportForAirPlayAndDontFileRadars",
            @"SBExtendedDisplayContentsScaleAndDontFileRadars",
            @"SBAppLibraryInDockEnabled",
            @"SBRecentsEnabled",
        ]];
    });
    return [keys containsObject:key];
}

@implementation TPPRootListController

- (void)viewDidLoad {
    [super viewDidLoad];
    [NSNotificationCenter.defaultCenter addObserver:self
        selector:@selector(applicationDidBecomeActive:)
        name:UIApplicationDidBecomeActiveNotification
        object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshStageManagerControls];
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    [self refreshStageManagerControls];
}

- (void)refreshStageManagerControls {
    if (!_specifiers) {
        return;
    }

    PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
    [stageManagerSideSpecifier setProperty:@(TPIsStageManagerEnabled()) forKey:PSEnabledKey];
    if (stageManagerSideSpecifier) {
        [self reloadSpecifier:stageManagerSideSpecifier animated:YES];
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specifiers = [[self loadSpecifiersFromPlistName:@"Root" target:self] mutableCopy];
        _specifiers = specifiers;
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:TPLocalized(@"Respring") style:UIBarButtonItemStylePlain target:self action:@selector(respring)];

        if (@available(iOS 17.0, *)) {
            PSSpecifier *systemMultitaskingSpecifier = [self specifierForID:TPSystemMultitaskingSpecifierID];
            systemMultitaskingSpecifier.cellType = PSButtonCell;
            systemMultitaskingSpecifier.detailControllerClass = Nil;
            systemMultitaskingSpecifier.target = self;
            systemMultitaskingSpecifier.buttonAction = @selector(openNativeMultitaskingSettings);
            systemMultitaskingSpecifier.name = TPLocalized(@"Multitasking & Gestures");
        }

        PSSpecifier *enableiPadKeyboardSpecifier = [self specifierForID:TPEnableiPadKeyboardSpecifierID];
        PSSpecifier *shortcutButtonsSpecifier = [self specifierForID:TPShowShortcutButtonsSpecifierID];
        BOOL enableiPadKeyboard = [[self readPreferenceValue:enableiPadKeyboardSpecifier] boolValue];
        [shortcutButtonsSpecifier setProperty:@(enableiPadKeyboard) forKey:PSEnabledKey];

        PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
        [stageManagerSideSpecifier setProperty:@(TPIsStageManagerEnabled()) forKey:PSEnabledKey];
    }
    return _specifiers;
}

- (void)openNativeMultitaskingSettings {
    Class controllerClass = TPLoadNativeMultitaskingController();
    if (!controllerClass) {
        NSLog(@"[TrollPadEx] Failed to load MultitaskingAndGesturesSettings.bundle");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:TPLocalized(@"Unavailable")
            message:TPLocalized(@"The system Multitasking & Gestures settings bundle could not be loaded.")
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:TPLocalized(@"OK") style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    id controller = [[controllerClass alloc] init];
    if (![controller isKindOfClass:UIViewController.class]) {
        NSLog(@"[TrollPadEx] Native controller is not a UIViewController: %@", controller);
        return;
    }
    if ([controller respondsToSelector:@selector(setRootController:)]) {
        [controller setRootController:self.rootController];
    }
    if ([controller respondsToSelector:@selector(setSpecifier:)]) {
        [controller setSpecifier:[self specifierForID:TPSystemMultitaskingSpecifierID]];
    }
    [self.navigationController pushViewController:controller animated:YES];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:PSKeyNameKey];
    id previousValue = [self readPreferenceValue:specifier];
    BOOL restartStageManager = [key isEqualToString:@"TPStageManagerSide"] &&
        ![previousValue isEqual:value] && TPIsStageManagerEnabled();

    [super setPreferenceValue:value specifier:specifier];

    if (restartStageManager) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
                TPRestartStageManager();
            });
    }

    if ([key isEqualToString:TPEnableiPadKeyboardKey]) {
        PSSpecifier *shortcutButtonsSpecifier = [self specifierForID:TPShowShortcutButtonsSpecifierID];
        [shortcutButtonsSpecifier setProperty:@([value boolValue]) forKey:PSEnabledKey];
        [self reloadSpecifier:shortcutButtonsSpecifier animated:YES];
    }

    if (TPPreferenceRequiresRespring(key) && !self.didShowRespringRequiredAlert) {
        self.didShowRespringRequiredAlert = YES;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:TPLocalized(@"Respring Required")
            message:TPLocalized(@"This system option is applied after a respring.")
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:TPLocalized(@"Later") style:UIAlertActionStyleCancel handler:nil]];
        __weak typeof(self) weakSelf = self;
        [alert addAction:[UIAlertAction actionWithTitle:TPLocalized(@"Respring Now") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [weakSelf respring];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)openDisplayArrangement {
    UIViewController *controller = [NSClassFromString(@"DBSArrangementViewController") new];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:controller];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)openSourceCode {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://github.com/khanhduytran0/TrollPad"] options:@{} completionHandler:nil];
}

- (void)openTwitter {
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://twitter.com/TranKha50277352"] options:@{} completionHandler:nil];
}

- (void)respring {
    NSURL *returnURL = [NSURL URLWithString:@"prefs:root=TrollPad"];
    SBSRelaunchAction *action = [NSClassFromString(@"SBSRelaunchAction") actionWithReason:@"RestartRenderServer" options:0 targetURL:returnURL];
    [[NSClassFromString(@"FBSSystemService") sharedService] sendActions:[NSSet setWithObject:action] withResult:nil];
}

@end
