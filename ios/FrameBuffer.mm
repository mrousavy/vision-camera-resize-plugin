//
//  FrameBuffer.mm
//  VisionCameraResizePlugin
//
//  Created by Marc Rousavy on 24.01.24.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import "FrameBuffer.h"
#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#import <VisionCamera/SharedArray.h>
#import <VisionCamera/VisionCameraProxyHolder.h>

@implementation FrameBuffer {
  vImage_Buffer _imageBuffer;
  SharedArray* _sharedArray;
}

- (instancetype)initWithWidth:(size_t)width
                       height:(size_t)height
                  pixelFormat:(ConvertPixelFormat)pixelFormat
                     dataType:(ConvertDataType)dataType
                        proxy:(VisionCameraProxyHolder*)proxy {
  if (self = [super init]) {
    _width = width;
    _height = height;
    _pixelFormat = pixelFormat;
    _dataType = dataType;

    size_t bytesPerPixel = [FrameBuffer getBytesPerPixel:pixelFormat withType:dataType];
    size_t size = width * height * bytesPerPixel;
    NSLog(@"Allocating SharedArray (size: %zu)...", size);
    _sharedArray = [[SharedArray alloc] initWithProxy:proxy allocateWithSize:size];
    _imageBuffer = vImage_Buffer{.width = width, .height = height, .data = _sharedArray.data, .rowBytes = width * bytesPerPixel};
  }
  return self;
}

@synthesize width = _width;
@synthesize height = _height;
@synthesize pixelFormat = _pixelFormat;
@synthesize dataType = _dataType;

- (size_t)channelsPerPixel {
  return [FrameBuffer getChannelsPerPixelForFormat:_pixelFormat];
}
- (size_t)bytesPerChannel {
  return [FrameBuffer getBytesForDataType:_dataType];
}
- (size_t)bytesPerPixel {
  return self.channelsPerPixel * self.bytesPerChannel;
}

- (SharedArray*)sharedArray {
  return _sharedArray;
}

- (const vImage_Buffer*)imageBuffer {
  return &_imageBuffer;
}

+ (size_t)getBytesForDataType:(ConvertDataType)dataType {
  switch (dataType) {
    case UINT8:
      // 8-bit uint
      return sizeof(uint8_t);
    case FLOAT32:
      // 32-bit float
      return sizeof(float);
  }
}

+ (size_t)getChannelsPerPixelForFormat:(ConvertPixelFormat)format {
  switch (format) {
    case RGB:
    case BGR:
      return 3;
    case RGBA:
    case ARGB:
    case BGRA:
    case ABGR:
      return 4;
  }
}

+ (size_t)getBytesPerPixel:(ConvertPixelFormat)format withType:(ConvertDataType)type {
  size_t channels = [FrameBuffer getChannelsPerPixelForFormat:format];
  size_t dataTypeSize = [FrameBuffer getBytesForDataType:type];
  return channels * dataTypeSize;
}

@end
