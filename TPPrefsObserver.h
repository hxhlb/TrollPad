#import <Foundation/Foundation.h>

@interface TPPrefsObserver : NSObject
@property(nonatomic, assign) BOOL allowLandscapeHomeScreen, forceEnableMedusaForLandscapeOnlyApps, hideStageManagerResizeCorners, useiPadAppSwitchingAnimation, isFloatingDockSupported, scaleGridSwitcher, mirrorStageManagerSwitcher;
@property(nonatomic, assign) NSInteger windowingMode, stageManagerSide;
@end
