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

typedef NS_ENUM(NSInteger, ConvertPixelFormat) {
  RGB_8,
  ARGB_8,
  RGBA_8,
  BGR_8,
  BGRA_8,
  ABGR_8
};

@interface ResizePlugin : FrameProcessorPlugin
@end

@implementation ResizePlugin {
  // Conversion
  SharedArray* _destinationArray;
  SharedArray* _argbArray;
  SharedArray* _rgbArray;
  // Resizing
  SharedArray* _resizeArray;
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
  return RGB_8;
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
  NSLog(@"Converting YUV Frame to ARGB_8...");
  
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
  NSLog(@"Converting ARGB_8 Frame to %zu...", destinationFormat);
  
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

- (void)convertFrame:(Frame*)frame
              toARGB:(const vImage_Buffer*)destination {
  NSLog(@"Converting BGRA_8 Frame to ARGB_8...");
  
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
  
  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  vImage_Buffer input {
    .data = CVPixelBufferGetBaseAddress(pixelBuffer),
    .width = frame.width,
    .height = frame.height,
    .rowBytes = frame.bytesPerRow
  };
  
  uint8_t permuteMap[4] = { 3, 2, 1, 0 };
  vImagePermuteChannels_ARGB8888(&input, destination, permuteMap, kvImageNoFlags);
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (vImage_Buffer)resizeARGB:(const vImage_Buffer*)buffer
                    toWidth:(size_t)width
                   toHeight:(size_t)height {
  NSLog(@"Resizing ARGB_8 Frame to %zu x %zu...", width, height);
  
  size_t resizeArraySize = width * height * 4;
  if (_resizeArray == nil || _resizeArray.count != resizeArraySize) {
    NSLog(@"Allocating _resizeArray (size: %zu)...", resizeArraySize);
    _resizeArray = [[SharedArray alloc] initWithProxy:_proxy
                                                 type:Uint8Array
                                                 size:resizeArraySize];
  }
  vImage_Buffer resizeDestination {
    .data = _resizeArray.data,
    .width = width,
    .height = height,
    .rowBytes = width * 4
  };
  // TODO: Preallocate tempBuffer? How big?
  vImageScale_ARGB8888(buffer, &resizeDestination, nil, kvImageNoFlags);
  
  return resizeDestination;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {

  // 1. Parse inputs
  size_t targetWidth = frame.width;
  size_t targetHeight = frame.height;
  NSDictionary* targetSize = arguments[@"size"];
  if (targetSize != nil) {
    targetWidth = ((NSNumber*) targetSize[@"width"]).intValue;
    targetHeight = ((NSNumber*) targetSize[@"height"]).intValue;
    NSLog(@"ResizePlugin: Target size: %zu x %zu", targetWidth, targetHeight);
  } else {
    NSLog(@"ResizePlugin: No custom target size supplied.");
  }
  
  ConvertPixelFormat pixelFormat = BGRA_8;
  NSString* pixelFormatString = arguments[@"pixelFormat"];
  if (pixelFormatString == nil) {
    pixelFormat = parsePixelFormat(pixelFormatString);
    NSLog(@"ResizePlugin: Using target format: %@", pixelFormatString);
  } else {
    NSLog(@"ResizePlugin: No custom target format supplied.");
  }

  FourCharCode sourceType = getFramePixelFormat(frame);
  
  // 3. Prepare destination buffer (write into JS SharedArray)
  size_t bytesPerPixel = getBytesPerPixel(pixelFormat);
  size_t arraySize = bytesPerPixel * targetWidth * targetHeight;
  if (_destinationArray == nil || _destinationArray.count != arraySize) {
    NSLog(@"Allocating _destinationArray (size: %zu)...", arraySize);
    _destinationArray = [[SharedArray alloc] initWithProxy:_proxy type:Uint8Array size:arraySize];
  }
  vImage_Buffer destination {
    .data = _destinationArray.data,
    .width = targetWidth,
    .height = targetHeight,
    .rowBytes = targetWidth * bytesPerPixel
  };
  
  // 4. Prepare ARGB_8888 array (intermediate type)
  size_t argbSize = 4 * frame.width * frame.height;
  if (_argbArray == nil || _argbArray.count != argbSize) {
    NSLog(@"Allocating _argbArray (size: %zu)...", argbSize);
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
    
    // 1. Convert YUV -> ARGB_8
    [self convertYUV:frame
               toRGB:kvImageARGB8888
                into:&argbDestination];
    
    // 2. Resize
    argbDestination = [self resizeARGB:&argbDestination toWidth:targetWidth toHeight:targetHeight];
    
    if (pixelFormat == ARGB_8) {
      // User wanted ARGB_8888, perfect - we already got that!
      return _resizeArray;
    } else {
      // User wanted another format, convert between RGB layouts.
      
      // 2. Convert ARGB_8 -> anything
      [self convertARGB:&argbDestination
                     to:pixelFormat
                   into:&destination];
      
      return _destinationArray;
    }
  } else if (sourceType == kCVPixelFormatType_32BGRA) {
    // Frame is in BGRA_8.
    
    // 1. Convert BGRA_8 -> ARGB_8
    [self convertFrame:frame toARGB:&argbDestination];
    
    // 2. Resize buffer
    argbDestination = [self resizeARGB:&argbDestination toWidth:targetWidth toHeight:targetHeight];
    
    // 3. Convert ARGB_8 -> anything
    [self convertARGB:&argbDestination
                   to:pixelFormat
                 into:&destination];
    
    // 4. Return to JS
    return _destinationArray;
  } else {
    [NSException raise:@"Invalid PixelFormat" format:@"Frame has invalid Pixel Format! Disable buffer compression and 10-bit HDR."];
    return nil;
  }
}

VISION_EXPORT_FRAME_PROCESSOR(ResizePlugin, resize);

@end
