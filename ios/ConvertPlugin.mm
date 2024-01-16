//
//  Convert.mm
//  VisionCameraResizePlugin
//
//  Created by Marc Rousavy on 16.01.24.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/Frame.h>
#import <VisionCamera/SharedArray.h>

#import <memory>
#import <utility>
#import <Accelerate/Accelerate.h>

typedef NS_ENUM(NSInteger, ConvertPixelFormat) {
  RGB_8,
  ARGB_8,
  RGBA_8,
  BGR_8,
  BGRA_8,
  ABGR_8
};

@interface ConvertPlugin : FrameProcessorPlugin
@end

@implementation ConvertPlugin {
  SharedArray* _destinationArray;
  SharedArray* _argbArray;
  SharedArray* _rgbArray;
  VisionCameraProxyHolder* _proxy;
}

- (instancetype) initWithProxy:(VisionCameraProxyHolder*)proxy
                   withOptions:(NSDictionary*)options {
  if (self = [super initWithProxy:proxy withOptions:options]) {
    _proxy = proxy;
  }
  return self;
}

ConvertPixelFormat parsePixelFormat(NSString* pixelFormat) {
  if ([pixelFormat isEqualToString:@"rgb (8-bit)"]) {
    return RGB_8;
  }
  if ([pixelFormat isEqualToString:@"rgba (8-bit)"]) {
    return RGBA_8;
  }
  if ([pixelFormat isEqualToString:@"argb (8-bit)"]) {
    return ARGB_8;
  }
  if ([pixelFormat isEqualToString:@"bgra (8-bit)"]) {
    return BGRA_8;
  }
  if ([pixelFormat isEqualToString:@"bgr (8-bit)"]) {
    return BGR_8;
  }
  if ([pixelFormat isEqualToString:@"abgr (8-bit)"]) {
    return ABGR_8;
  }
  [NSException raise:@"Invalid PixelFormat" format:@"Invalid PixelFormat passed! (%@)", pixelFormat];
}

size_t getBytesPerPixel(ConvertPixelFormat format) {
  switch (format) {
    case RGB_8:
    case BGR_8:
      return 3;
    case RGBA_8:
    case ARGB_8:
    case BGRA_8:
    case ABGR_8:
      return 4;
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

- (void)convertYUV:(Frame*)frame
             toRGB:(vImageARGBType)targetType
              into:(const vImage_Buffer*)destination {
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
  
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

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
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)convertARGB:(const vImage_Buffer*)buffer
                 to:(ConvertPixelFormat)destinationFormat
               into:(const vImage_Buffer*)destination {
  
  switch (destinationFormat) {
    case RGB_8: {
      uint8_t backgroundColor[3] { 0, 0, 0 };
      vImageFlatten_ARGB8888ToRGB888(buffer, destination, backgroundColor, false, kvImageNoFlags);
      break;
    }
    case BGR_8: {
      uint8_t backgroundColor[3] { 0, 0, 0 };
      vImageFlatten_ARGB8888ToRGB888(buffer, destination, backgroundColor, false, kvImageNoFlags);
      uint8_t permuteMap[4] = { 2, 1, 0 };
      // TODO: Can I use the existing in-memory buffer or do I need a separate one?
      vImagePermuteChannels_RGB888(destination, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ARGB_8: {
      // We are already in ARGB_8.
      break;
    }
    case RGBA_8: {
      uint8_t permuteMap[4] = { 3, 1, 2, 0 };
      vImagePermuteChannels_ARGB8888(buffer, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case BGRA_8: {
      uint8_t permuteMap[4] = { 3, 2, 1, 0 };
      vImagePermuteChannels_ARGB8888(buffer, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ABGR_8: {
      uint8_t permuteMap[4] = { 0, 3, 2, 1 };
      vImagePermuteChannels_ARGB8888(buffer, destination, permuteMap, kvImageNoFlags);
      break;
    }
  }
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);

  // 1. Parse inputs
  NSString* pixelFormatString = arguments[@"pixelFormat"];
  if (pixelFormatString == nil) {
    [NSException raise:@"No PixelFormat" format:@"No pixelFormat was passed to convert(..)!"];
  }
  ConvertPixelFormat pixelFormat = parsePixelFormat(pixelFormatString);

  FourCharCode sourceType = getFramePixelFormat(frame);
  
  // 3. Prepare destination buffer (write into JS SharedArray)
  size_t bytesPerPixel = getBytesPerPixel(pixelFormat);
  size_t arraySize = bytesPerPixel * frame.width * frame.height;
  if (_destinationArray == nil || _destinationArray.count != arraySize) {
    _destinationArray = [[SharedArray alloc] initWithProxy:_proxy type:Uint8Array size:arraySize];
  }
  vImage_Buffer destination {
    .data = _destinationArray.data,
    .width = frame.width,
    .height = frame.height,
    .rowBytes = frame.width * bytesPerPixel
  };
  
  // 4. Prepare ARGB_8888 array (intermediate type)
  size_t argbSize = 4 * frame.width * frame.height;
  if (_argbArray == nil || _argbArray.count != argbSize) {
    _argbArray = [[SharedArray alloc] initWithProxy:_proxy type:Uint8Array size:argbSize];
  }
  vImage_Buffer argbDestination {
    .data = _argbArray.data,
    .width = frame.width,
    .height = frame.height,
    .rowBytes = frame.width * 4
  };
  
  // 5. Do the actual conversions
  if (sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
    // Convert YUV (4:2:0) -> ARGB_8888 first, only then we can operate in RGB layouts
    
    // Convert Frame
    [self convertYUV:frame
               toRGB:kvImageARGB8888
                into:&argbDestination];
    
    if (pixelFormat == ARGB_8) {
      // User wanted ARGB_8888, perfect - we already got that!
      return _argbArray;
    } else {
      // User wanted another format, convert between RGB layouts.
      
      // ARGB_8 -> anything
      [self convertARGB:&argbDestination
                     to:pixelFormat
                   into:&destination];
      
      return _destinationArray;
    }
  } else if (sourceType == kCVPixelFormatType_32BGRA) {
    // Frame is in 32BGRA.
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    vImage_Buffer input {
      .data = CVPixelBufferGetBaseAddress(pixelBuffer),
      .width = frame.width,
      .height = frame.height,
      .rowBytes = frame.bytesPerRow
    };
    
    // BGRA_8 -> ARGB_8
    uint8_t permuteMap[4] = { 3, 2, 1, 0 };
    vImagePermuteChannels_ARGB8888(&input, &argbDestination, permuteMap, kvImageNoFlags);
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    // BGRA_8 -> anything
    [self convertARGB:&argbDestination
                   to:pixelFormat
                 into:&destination];
    
    return _destinationArray;
  } else {
    [NSException raise:@"Invalid PixelFormat" format:@"Frame has invalid Pixel Format! Disable buffer compression and 10-bit HDR."];
  }
}

VISION_EXPORT_FRAME_PROCESSOR(ConvertPlugin, convert);

@end
