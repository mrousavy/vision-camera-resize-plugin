//
//  VisionCameraResizePlugin.m
//  VisionCameraExample
//
//  Created by Marc Rousavy on 06.05.21.
//

#import <VisionCamera/FrameProcessorPlugin.h>
@import Foundation;
@import AVFoundation;

@interface FrameProcessorResizePlugin : NSObject
@end

@implementation FrameProcessorResizePlugin

static inline id resize(CMSampleBufferRef buffer, NSArray* arguments) {
  NSNumber* width = [arguments objectAtIndex:0];
  NSNumber* height = [arguments objectAtIndex:1];
  if (width == nil || height == nil) {
    return nil;
  }
  if (width.intValue <= 0 || height.intValue <= 0) {
    return nil;
  }
  
  return buffer;
}

VISION_EXPORT_FRAME_PROCESSOR(resize)

@end
