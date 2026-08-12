#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>
#import "TPPRootListController.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.kdt.trollpad.plist"

static NSString *const TPEnableiPadKeyboardKey = @"TPEnableiPadKeyboard";
static NSString *const TPEnableiPadKeyboardSpecifierID = @"ENABLE_IPAD_KEYBOARD";
static NSString *const TPShowShortcutButtonsSpecifierID = @"SHOW_SHORTCUT_BUTTONS";
static NSString *const TPWindowingModeKey = @"TPWindowingMode";
static NSString *const TPWindowingModeSpecifierID = @"WINDOWING_MODE";
static NSString *const TPStageManagerSideKey = @"TPStageManagerSide";
static NSString *const TPStageManagerSideSpecifierID = @"STAGE_MANAGER_SIDE";
static NSString *const TPMirrorStageManagerSwitcherSpecifierID = @"MIRROR_STAGE_MANAGER_SWITCHER";
static NSInteger const TPWindowingModeStageManager = 2;
static NSInteger const TPStageManagerSideRight = 1;

@implementation TPPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStylePlain target:self action:@selector(respring)];

        PSSpecifier *enableiPadKeyboardSpecifier = [self specifierForID:TPEnableiPadKeyboardSpecifierID];
        PSSpecifier *shortcutButtonsSpecifier = [self specifierForID:TPShowShortcutButtonsSpecifierID];
        BOOL enableiPadKeyboard = [[self readPreferenceValue:enableiPadKeyboardSpecifier] boolValue];
        [shortcutButtonsSpecifier setProperty:@(enableiPadKeyboard) forKey:PSEnabledKey];

        PSSpecifier *windowingModeSpecifier = [self specifierForID:TPWindowingModeSpecifierID];
        PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger windowingMode = [[self readPreferenceValue:windowingModeSpecifier] integerValue];
        NSInteger stageManagerSide = [[self readPreferenceValue:stageManagerSideSpecifier] integerValue];
        [stageManagerSideSpecifier setProperty:@(windowingMode == TPWindowingModeStageManager) forKey:PSEnabledKey];
        [mirrorStageManagerSwitcherSpecifier setProperty:@(windowingMode == TPWindowingModeStageManager && stageManagerSide == TPStageManagerSideRight) forKey:PSEnabledKey];
    }
    return _specifiers;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];

    if ([[specifier propertyForKey:PSKeyNameKey] isEqualToString:TPEnableiPadKeyboardKey]) {
        PSSpecifier *shortcutButtonsSpecifier = [self specifierForID:TPShowShortcutButtonsSpecifierID];
        [shortcutButtonsSpecifier setProperty:@([value boolValue]) forKey:PSEnabledKey];
        [self reloadSpecifier:shortcutButtonsSpecifier animated:YES];
    }

    if ([[specifier propertyForKey:PSKeyNameKey] isEqualToString:TPWindowingModeKey]) {
        PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger stageManagerSide = [[self readPreferenceValue:stageManagerSideSpecifier] integerValue];
        [stageManagerSideSpecifier setProperty:@([value integerValue] == TPWindowingModeStageManager) forKey:PSEnabledKey];
        [mirrorStageManagerSwitcherSpecifier setProperty:@([value integerValue] == TPWindowingModeStageManager && stageManagerSide == TPStageManagerSideRight) forKey:PSEnabledKey];
        [self reloadSpecifier:stageManagerSideSpecifier animated:YES];
        [self reloadSpecifier:mirrorStageManagerSwitcherSpecifier animated:YES];
    }

    if ([[specifier propertyForKey:PSKeyNameKey] isEqualToString:TPStageManagerSideKey]) {
        PSSpecifier *windowingModeSpecifier = [self specifierForID:TPWindowingModeSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger windowingMode = [[self readPreferenceValue:windowingModeSpecifier] integerValue];
        [mirrorStageManagerSwitcherSpecifier setProperty:@(windowingMode == TPWindowingModeStageManager && [value integerValue] == TPStageManagerSideRight) forKey:PSEnabledKey];
        [self reloadSpecifier:mirrorStageManagerSwitcherSpecifier animated:YES];
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
