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
}

- (instancetype) initWithOptions:(NSDictionary*)options; {
  self = [super init];
  NSNumber* width = (NSNumber*) options[@"targetWidth"];
  NSNumber* height = (NSNumber*) options[@"targetHeight"];
  NSAssert(width != nil && height != nil, "targetWidth or targetHeight are required parameters!");
  NSNumber* channelSize = (NSNumber*) options[@"channelSize"];
  
  _frameResizer = std::make_unique<FrameResizer>((size_t) width.intValue,
                                                 (size_t) height.intValue,
                                                 (size_t) channelSize.intValue);
  return self;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  
  vImage_Buffer& resizedFrame = _frameResizer->resizeFrame(pixelBuffer);
  // code goes here
  return @[];
}

+ (void) load {
  [FrameProcessorPluginRegistry addFrameProcessorPlugin:@"detectFaces"
                                        withInitializer:^FrameProcessorPlugin*(NSDictionary* options) {
    return [[FaceDetectorFrameProcessorPlugin alloc] initWithOptions:options];
  }];
}

@end
