//
//  ResizePlugin.mm
//  VisionCameraResizePlugin
//
//  Created by Marc Rousavy on 23.09.23.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>

#import "FrameResizer.h"
#import <memory>
#import <utility>

@interface ResizePlugin : FrameProcessorPlugin
@end

@implementation ResizePlugin {
  std::unique_ptr<FrameResizer> _frameResizer;
  VisionCameraProxyHolder* _proxy;
}

- (instancetype) initWithProxy:(VisionCameraProxyHolder*)proxy
                   withOptions:(NSDictionary*)options {
  if (self = [super initWithProxy:proxy withOptions:options]) {
    _proxy = proxy;
  }
  return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  
  NSNumber* width = arguments[@"width"];
  NSNumber* height = arguments[@"height"];
  if (width != nil && height != nil && width.intValue != frame.width && height.intValue != frame.height) {
    // TODO: Resize
  }
  
  NSString* format = arguments[@"format"];
  if (format != nil) {
    // TODO: Convert format
  }
  
  const vImage_Buffer& resizedFrame = _frameResizer->resizeFrame(pixelBuffer);
  // code goes here
  return @[];
}

VISION_EXPORT_FRAME_PROCESSOR(ResizePlugin, resize);

@end
