#import <RCTDefaultReactNativeFactoryDelegate.h>
#import <UIKit/UIKit.h>

@class RCTReactNativeFactory;

@interface AppDelegate : RCTDefaultReactNativeFactoryDelegate <UIApplicationDelegate>

@property(nonatomic, strong) UIWindow* window;
@property(nonatomic, strong) RCTReactNativeFactory* reactNativeFactory;

@end
