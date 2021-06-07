//
//  VisionCameraResizePlugin.m
//  VisionCameraExample
//
//  Created by Marc Rousavy on 06.05.21.
//

#import <VisionCamera/FrameProcessorPlugin.h>
@import Foundation;
@import AVFoundation;

// Example for an Objective-C Frame Processor plugin

@interface QRCodeFrameProcessorPluginObjC : NSObject

+ (MLKResizePlugin*) labeler;

@end

@implementation QRCodeFrameProcessorPluginObjC

+ (MLKResizePlugin*) labeler {
  static MLKResizePlugin* labeler = nil;
  if (labeler == nil) {
    MLKResizePluginOptions* options = [[MLKResizePluginOptions alloc] init];
    labeler = [MLKResizePlugin ResizePluginWithOptions:options];
  }
  return labeler;
}

static inline id labelImage(CMSampleBufferRef buffer, NSArray* arguments) {
  MLKVisionImage *image = [[MLKVisionImage alloc] initWithBuffer:buffer];
  image.orientation = UIImageOrientationRight; // <-- TODO: is mirrored?

  NSError* error;
  NSArray<MLKImageLabel*>* labels = [[QRCodeFrameProcessorPluginObjC labeler] resultsInImage:image error:&error];

  NSMutableArray* results = [NSMutableArray arrayWithCapacity:labels.count];
  for (MLKImageLabel* label in labels) {
    [results addObject:@{
      @"label": label.text,
      @"confidence": [NSNumber numberWithFloat:label.confidence]
    }];
  }

  return results;
}

VISION_EXPORT_FRAME_PROCESSOR(labelImage)

@end
