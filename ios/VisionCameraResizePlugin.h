#ifdef __cplusplus
#import "vision-camera-resize-plugin.h"
#endif

#ifdef RCT_NEW_ARCH_ENABLED
#import "RNVisionCameraResizePluginSpec.h"

@interface VisionCameraResizePlugin : NSObject <NativeVisionCameraResizePluginSpec>
#else
#import <React/RCTBridgeModule.h>

@interface VisionCameraResizePlugin : NSObject <RCTBridgeModule>
#endif

@end
