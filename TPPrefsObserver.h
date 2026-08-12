#import <Foundation/Foundation.h>

@interface TPPrefsObserver : NSObject
@property(nonatomic, assign) BOOL allowLandscapeHomeScreen, forceEnableMedusaForLandscapeOnlyApps, hideStageManagerResizeCorners, useiPadAppSwitchingAnimation, isFloatingDockSupported, scaleGridSwitcher, mirrorAppSwitcher;
@property(nonatomic, assign) NSInteger stageManagerSide;
@end
