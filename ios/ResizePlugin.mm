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
#import <VisionCamera/SharedArray.h>

#import <memory>
#import <utility>
#import <Accelerate/Accelerate.h>

typedef NS_ENUM(NSInteger, ResizePixelFormat) {
  YUV_420_8,
  YUV_422_8,
  YUV_444_8,
  YUV_420_10,
  YUV_422_10,
  YUV_444_10,
  RGB_8,
  ARGB_8,
  BGR_8,
  BGRA_8
};

@interface ResizePlugin : FrameProcessorPlugin
@end

@implementation ResizePlugin {
  SharedArray* _array;
  VisionCameraProxyHolder* _proxy;
}

- (instancetype) initWithProxy:(VisionCameraProxyHolder*)proxy
                   withOptions:(NSDictionary*)options {
  if (self = [super initWithProxy:proxy withOptions:options]) {
    _proxy = proxy;
  }
  return self;
}

ResizePixelFormat parsePixelFormat(NSString* pixelFormat) {
  if ([pixelFormat isEqualToString:@"yuv (4:2:0) 8-bit"]) {
    return YUV_420_8;
  }
  if ([pixelFormat isEqualToString:@"yuv (4:2:2) 8-bit"]) {
    return YUV_422_8;
  }
  if ([pixelFormat isEqualToString:@"yuv (4:4:4) 8-bit"]) {
    return YUV_444_8;
  }
  if ([pixelFormat isEqualToString:@"yuv (4:2:0) 10-bit"]) {
    return YUV_420_10;
  }
  if ([pixelFormat isEqualToString:@"yuv (4:2:2) 10-bit"]) {
    return YUV_422_10;
  }
  if ([pixelFormat isEqualToString:@"yuv (4:4:4) 10-bit"]) {
    return YUV_444_10;
  }
  if ([pixelFormat isEqualToString:@"rgb"]) {
    return RGB_8;
  }
  if ([pixelFormat isEqualToString:@"argb"]) {
    return ARGB_8;
  }
  if ([pixelFormat isEqualToString:@"bgr"]) {
    return BGR_8;
  }
  if ([pixelFormat isEqualToString:@"bgra"]) {
    return BGRA_8;
  }
}

FourCharCode getFramePixelFormat(Frame* frame) {
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(frame.buffer);
  return CMFormatDescriptionGetMediaSubType(format);
}

vImageYpCbCrType getFramevImageFormat(Frame* frame) {
  FourCharCode subType = getFramePixelFormat(frame);
  switch (subType) {
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
      return kvImage420Yp8_CbCr8;
    case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
      throw std::runtime_error("Invalid Pixel Format! 10-bit HDR is not supported.");
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange:
    case kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange:
      throw std::runtime_error("Invalid Pixel Format! Buffer compression is not supported.");
    default:
      throw std::runtime_error("Invalid PixelFormat!");
  }
}

int getBytesPerPixel(ResizePixelFormat pixelFormat) {
  switch (pixelFormat) {
    case RGB_8:
    case BGR_8:
      return 3;
    case ARGB_8:
    case BGRA_8:
      return 4;
  }
}

int getTotalSizeOfImage(int width, int height, ResizePixelFormat pixelFormat) {
  return width * height * getBytesPerPixel(pixelFormat);
}

- (void)convert:(Frame*)frame to:(vImageARGBType)targetType into:(const vImage_Buffer*)destination {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  
  vImage_YpCbCrPixelRange range {
    .Yp_bias = 64,
    .CbCr_bias = 512,
    .YpRangeMax = 940,
    .CbCrRangeMax = 960,
    .YpMax = 255,
    .YpMin = 0,
    .CbCrMax = 255,
    .CbCrMin = 0
  };
  
  vImage_YpCbCrToARGB info;
  vImageYpCbCrType sourcevImageFormat = getFramevImageFormat(frame);
  vImage_Error error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4,
                                                                     &range,
                                                                     &info,
                                                                     sourcevImageFormat,
                                                                     targetType,
                                                                     kvImageNoFlags);
  
  
  vImage_Buffer sourceY = {
    .data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
    .width = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
    .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
    .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
  };
  vImage_Buffer sourceCbCr = {
    .data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
    .width = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
    .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
    .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
  };
  
  vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceY, &sourceCbCr, destination, &info, nil, 255, kvImageNoFlags);
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  
  // 1. Prepare destination buffer (write into JS SharedArray)
  size_t width = frame.width;
  size_t height = frame.height;
  size_t bytesPerRow = frame.bytesPerRow;
  
  NSDictionary* size = arguments[@"size"];
  if (size != nil) {
    width = ((NSNumber*) size[@"width"]).intValue;
    height = ((NSNumber*) size[@"height"]).intValue;
  }
  NSString* pixelFormat = arguments[@"pixelFormat"];
  if (pixelFormat != nil) {
    ResizePixelFormat parsed = parsePixelFormat(pixelFormat);
    size_t bytesPerPixel = getBytesPerPixel(parsed);
    bytesPerRow = bytesPerPixel * width;
  }
  
  size_t arraySize = bytesPerRow * height;
  
  // 2. Make sure destination buffer is correct size, if not, resize
  if (_array == nil || _array.count != arraySize) {
    _array = [[SharedArray alloc] initWithProxy:_proxy
                                           type:Uint8Array
                                           size:arraySize];
  }
  vImage_Buffer destination {
    .data = _array.data,
    .width = width,
    .height = height,
    .rowBytes = bytesPerRow
  };
  
  
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  // 3. Convert Format
  NSString* format = arguments[@"format"];
  if (format != nil) {
    ResizePixelFormat pixelFormat = parsePixelFormat(format);
    FourCharCode sourceType = getFramePixelFormat(frame);
    
    if (sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
      // Convert YUV (4:2:0) -> RGB
      [self convert:frame to:kvImageARGB8888 into:&destination];
    } else if (sourceType == kCVPixelFormatType_32BGRA) {
      throw std::runtime_error("Cannot convert 32BGRA yet!");
    }
  }
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  return _array;
}

VISION_EXPORT_FRAME_PROCESSOR(ResizePlugin, resize);

@end
