#import <Foundation/Foundation.h>

@interface TPPrefsObserver : NSObject
@property(nonatomic, assign) BOOL allowLandscapeHomeScreen, forceEnableMedusaForLandscapeOnlyApps, hideStageManagerResizeCorners, useiPadAppSwitchingAnimation, isFloatingDockSupported, scaleGridSwitcher;
@property(nonatomic, assign) NSInteger multitaskingMode, stageManagerSide;
@end
