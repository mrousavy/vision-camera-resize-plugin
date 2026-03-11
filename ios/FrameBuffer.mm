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

@implementation FrameBuffer {
  vImage_Buffer _imageBuffer;
  void* _data;
}

- (instancetype)initWithWidth:(size_t)width
                       height:(size_t)height
                  pixelFormat:(ConvertPixelFormat)pixelFormat
                     dataType:(ConvertDataType)dataType {
  if (self = [super init]) {
    _width = width;
    _height = height;
    _pixelFormat = pixelFormat;
    _dataType = dataType;

    size_t bytesPerPixel = [FrameBuffer getBytesPerPixel:pixelFormat withType:dataType];
    _size = width * height * bytesPerPixel;
    _data = malloc(_size);
    if (_data == nil) {
      @throw [NSException exceptionWithName:@"FrameBuffer allocation error"
                                     reason:[NSString stringWithFormat:@"Failed to allocate %zu bytes", _size]
                                   userInfo:nil];
    }
    _imageBuffer = vImage_Buffer{.width = width, .height = height, .data = _data, .rowBytes = width * bytesPerPixel};
  }
  return self;
}

- (void)dealloc {
  free(_data);
}

@synthesize width = _width;
@synthesize height = _height;
@synthesize pixelFormat = _pixelFormat;
@synthesize dataType = _dataType;
@synthesize size = _size;

- (size_t)channelsPerPixel {
  return [FrameBuffer getChannelsPerPixelForFormat:_pixelFormat];
}
- (size_t)bytesPerChannel {
  return [FrameBuffer getBytesForDataType:_dataType];
}
- (size_t)bytesPerPixel {
  return self.channelsPerPixel * self.bytesPerChannel;
}

- (void*)data {
  return _data;
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
