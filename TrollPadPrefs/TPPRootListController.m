#import <Foundation/Foundation.h>
#import <Preferences/PSSpecifier.h>
#import "TPPRootListController.h"

#define PREF_PATH @"/var/mobile/Library/Preferences/com.kdt.trollpad.plist"

static NSString *const TPEnableiPadKeyboardKey = @"TPEnableiPadKeyboard";
static NSString *const TPEnableiPadKeyboardSpecifierID = @"ENABLE_IPAD_KEYBOARD";
static NSString *const TPShowShortcutButtonsSpecifierID = @"SHOW_SHORTCUT_BUTTONS";
static NSString *const TPMultitaskingModeKey = @"TPMultitaskingMode";
static NSString *const TPMultitaskingModeSpecifierID = @"MULTITASKING_MODE";
static NSString *const TPStageManagerSideKey = @"TPStageManagerSide";
static NSString *const TPStageManagerSideSpecifierID = @"STAGE_MANAGER_SIDE";
static NSString *const TPMirrorStageManagerSwitcherSpecifierID = @"MIRROR_STAGE_MANAGER_SWITCHER";
static NSInteger const TPMultitaskingModeStageManager = 3;
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

        PSSpecifier *multitaskingModeSpecifier = [self specifierForID:TPMultitaskingModeSpecifierID];
        PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger multitaskingMode = [[self readPreferenceValue:multitaskingModeSpecifier] integerValue];
        NSInteger stageManagerSide = [[self readPreferenceValue:stageManagerSideSpecifier] integerValue];
        [stageManagerSideSpecifier setProperty:@(multitaskingMode == TPMultitaskingModeStageManager) forKey:PSEnabledKey];
        [mirrorStageManagerSwitcherSpecifier setProperty:@(multitaskingMode == TPMultitaskingModeStageManager && stageManagerSide == TPStageManagerSideRight) forKey:PSEnabledKey];
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

    if ([[specifier propertyForKey:PSKeyNameKey] isEqualToString:TPMultitaskingModeKey]) {
        PSSpecifier *stageManagerSideSpecifier = [self specifierForID:TPStageManagerSideSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger stageManagerSide = [[self readPreferenceValue:stageManagerSideSpecifier] integerValue];
        [stageManagerSideSpecifier setProperty:@([value integerValue] == TPMultitaskingModeStageManager) forKey:PSEnabledKey];
        [mirrorStageManagerSwitcherSpecifier setProperty:@([value integerValue] == TPMultitaskingModeStageManager && stageManagerSide == TPStageManagerSideRight) forKey:PSEnabledKey];
        [self reloadSpecifier:stageManagerSideSpecifier animated:YES];
        [self reloadSpecifier:mirrorStageManagerSwitcherSpecifier animated:YES];
    }

    if ([[specifier propertyForKey:PSKeyNameKey] isEqualToString:TPStageManagerSideKey]) {
        PSSpecifier *multitaskingModeSpecifier = [self specifierForID:TPMultitaskingModeSpecifierID];
        PSSpecifier *mirrorStageManagerSwitcherSpecifier = [self specifierForID:TPMirrorStageManagerSwitcherSpecifierID];
        NSInteger multitaskingMode = [[self readPreferenceValue:multitaskingModeSpecifier] integerValue];
        [mirrorStageManagerSwitcherSpecifier setProperty:@(multitaskingMode == TPMultitaskingModeStageManager && [value integerValue] == TPStageManagerSideRight) forKey:PSEnabledKey];
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
