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

#import "FrameBuffer.h"

@interface ResizePlugin : FrameProcessorPlugin
@end

@implementation ResizePlugin {
  // 1. ??? (?x?) -> ARGB (?x?)
  FrameBuffer* _argbBuffer;
  // 2. ARGB (?x?) -> ARGB (!x!)
  FrameBuffer* _resizeBuffer;
  // 3. ARGB (!x!) -> !!!! (!x!)
  FrameBuffer* _convertBuffer;
  // 4. uint8 -> other type (e.g. float32) if needed
  FrameBuffer* _customTypeBuffer;
  
  // Cache
  void* _tempResizeBuffer;
  VisionCameraProxyHolder* _proxy;
}

- (instancetype) initWithProxy:(VisionCameraProxyHolder*)proxy
                   withOptions:(NSDictionary*)options {
  if (self = [super initWithProxy:proxy withOptions:options]) {
    _proxy = proxy;
  }
  return self;
}

- (void)dealloc {
  NSLog(@"Deallocating ResizePlugin...");
  free(_tempResizeBuffer);
}

ConvertPixelFormat parsePixelFormat(NSString* pixelFormat) {
  if ([pixelFormat isEqualToString:@"rgb"]) {
    return RGB;
  }
  if ([pixelFormat isEqualToString:@"rgba"]) {
    return RGBA;
  }
  if ([pixelFormat isEqualToString:@"argb"]) {
    return ARGB;
  }
  if ([pixelFormat isEqualToString:@"bgra"]) {
    return BGRA;
  }
  if ([pixelFormat isEqualToString:@"bgr"]) {
    return BGR;
  }
  if ([pixelFormat isEqualToString:@"abgr"]) {
    return ABGR;
  }
  [NSException raise:@"Invalid PixelFormat" format:@"Invalid PixelFormat passed! (%@)", pixelFormat];
  return RGB;
}

ConvertDataType parseDataType(NSString* dataType) {
  if ([dataType isEqualToString:@"uint8"]) {
    return UINT8;
  }
  if ([dataType isEqualToString:@"float32"]) {
    return FLOAT32;
  }
  [NSException raise:@"Invalid DataType" format:@"Invalid DataType passed! (%@)", dataType];
  return UINT8;
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

vImage_YpCbCrPixelRange getRange(FourCharCode pixelFormat) {
  // Values are from vImage_Types.h::vImage_YpCbCrPixelRange
  switch (pixelFormat) {
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
      return (vImage_YpCbCrPixelRange){ 0, 128, 255, 255, 255, 1, 255, 0 };
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
      return (vImage_YpCbCrPixelRange){ 16, 128, 235, 240, 235, 16, 240, 16 };
    default:
      [NSException raise:@"Unknown YUV pixel format!" format:@"Frame Pixel format is not supported in vImage_YpCbCrPixelRange!"];
      return (vImage_YpCbCrPixelRange) { };
  }
}

- (FrameBuffer*)convertYUV:(Frame*)frame
                     toRGB:(vImageARGBType)targetType {
  NSLog(@"Converting YUV Frame to RGB...");
  vImage_Error error = kvImageNoError;

  vImage_YpCbCrPixelRange range = getRange(getFramePixelFormat(frame));

  vImage_YpCbCrToARGB info;
  vImageYpCbCrType sourcevImageFormat = getFramevImageFormat(frame);
  error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4,
                                                        &range,
                                                        &info,
                                                        sourcevImageFormat,
                                                        targetType,
                                                        kvImageNoFlags);
  if (error != kvImageNoError) {
    [NSException raise:@"YUV -> RGB conversion error" format:@"Failed to create YUV -> RGB conversion! Error: %zu", error];
  }

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
  
  if (_argbBuffer == nil || _argbBuffer.width != frame.width || _argbBuffer.height != frame.height) {
    _argbBuffer = [[FrameBuffer alloc] initWithWidth:frame.width
                                              height:frame.height
                                         pixelFormat:ARGB
                                            dataType:UINT8
                                               proxy:_proxy];
  }
  const vImage_Buffer* destination = _argbBuffer.imageBuffer;

  error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceY,
                                               &sourceCbCr,
                                               destination,
                                               &info,
                                               nil,
                                               255,
                                               kvImageNoFlags);
  if (error != kvImageNoError) {
    [NSException raise:@"YUV -> RGB conversion error" format:@"Failed to run YUV -> RGB conversion! Error: %zu", error];
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
  
  return _argbBuffer;
}

- (FrameBuffer*)convertARGB:(FrameBuffer*)buffer
                         to:(ConvertPixelFormat)destinationFormat {
  vImage_Error error = kvImageNoError;
  Pixel_8888 backgroundColor { 0, 0, 0, 255 };
  
  // If possible, do all conversions in-memory.
  FrameBuffer* destinationBuffer = buffer;
  
  size_t targetBytesPerPixel = [FrameBuffer getBytesPerPixel:destinationFormat withType:UINT8];
  if (buffer.bytesPerPixel != targetBytesPerPixel) {
    // The bytes per pixel are not the same, so we need an intermediate array allocation.
    if (_convertBuffer == nil || _convertBuffer.width != buffer.width || _convertBuffer.height != buffer.height || _convertBuffer.pixelFormat != destinationFormat) {
      _convertBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width
                                                   height:buffer.height
                                              pixelFormat:destinationFormat
                                                 dataType:UINT8
                                                    proxy:_proxy];
    }
    destinationBuffer = _convertBuffer;
  }
  
  // Source and Destination _might_ be the same buffer.
  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = destinationBuffer.imageBuffer;

  switch (destinationFormat) {
    case RGB: {
      NSLog(@"Converting ARGB_8 Frame to RGB_8...");
      error = vImageFlatten_ARGB8888ToRGB888(source, destination, backgroundColor, false, kvImageNoFlags);
      break;
    }
    case BGR: {
      NSLog(@"Converting ARGB_8 Frame to BGR_8...");
      error = vImageFlatten_ARGB8888ToRGB888(source, destination, backgroundColor, false, kvImageNoFlags);
      uint8_t permuteMap[4] = { 2, 1, 0 };
      error = vImagePermuteChannels_RGB888(destination, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ARGB: {
      // We are already in ARGB_8. No need to do anything.
      break;
    }
    case RGBA: {
      NSLog(@"Converting ARGB_8 Frame to RGBA_8...");
      uint8_t permuteMap[4] = { 3, 1, 2, 0 };
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case BGRA: {
      NSLog(@"Converting ARGB_8 Frame to BGRA_8...");
      uint8_t permuteMap[4] = { 3, 2, 1, 0 };
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ABGR: {
      NSLog(@"Converting ARGB_8 Frame to ABGR_8...");
      uint8_t permuteMap[4] = { 0, 3, 2, 1 };
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
  }

  if (error != kvImageNoError) {
    [NSException raise:@"RGB Conversion Error" format:@"Failed to convert RGB layout! Error: %zu", error];
  }
  
  return destinationBuffer;
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
  vImage_Error error = vImagePermuteChannels_ARGB8888(&input, destination, permuteMap, kvImageNoFlags);
  if (error != kvImageNoError) {
    [NSException raise:@"RGB Conversion Error" format:@"Failed to convert Frame to ARGB! Error: %zu", error];
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (FrameBuffer*)resizeARGB:(FrameBuffer*)buffer
                   toWidth:(size_t)width
                  toHeight:(size_t)height {
  if (buffer.width == width && buffer.height == height) {
    // We are already in the target size.
    NSLog(@"Skipping resize, buffer is already desired size (%zu x %zu)...", width, height);
    return buffer;
  }

  NSLog(@"Resizing ARGB_8 Frame to %zu x %zu...", width, height);

  if (_resizeBuffer == nil || _resizeBuffer.width != width || _resizeBuffer.height != height) {
    _resizeBuffer = [[FrameBuffer alloc] initWithWidth:width
                                                height:height
                                           pixelFormat:ARGB
                                              dataType:UINT8
                                                 proxy:_proxy];
    // reset _tempResizeBuffer as well as that depends on the size
    free(_tempResizeBuffer);
    _tempResizeBuffer = nil;
  }
  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = _resizeBuffer.imageBuffer;
  
  if (_tempResizeBuffer == nil) {
    size_t tempBufferSize = vImageScale_ARGB8888(source, destination, nil, kvImageGetTempBufferSize);
    if (tempBufferSize > 0) {
      NSLog(@"Allocating _tempResizeBuffer (size: %zu)...", tempBufferSize);
      free(_tempResizeBuffer);
      _tempResizeBuffer = malloc(tempBufferSize);
    } else {
      NSLog(@"Cannot allocate _tempResizeBuffer, size is unknown!");
    }
  }

  vImage_Error error = vImageScale_ARGB8888(source, destination, _tempResizeBuffer, kvImageNoFlags);
  if (error != kvImageNoError) {
    [NSException raise:@"Resize Error" format:@"Failed to resize ARGB buffer! Error: %zu", error];
  }

  return _resizeBuffer;
}

- (FrameBuffer*)convertInt8Buffer:(FrameBuffer*)buffer
                       toDataType:(ConvertDataType)targetType {
  if (buffer.dataType == targetType) {
    // we are already in the target type
    return buffer;
  }
  
  NSLog(@"Converting uint8 (%zu) buffer to target type (%zu)...", buffer.dataType, targetType);
  
  if (_customTypeBuffer == nil || _customTypeBuffer.width != buffer.width || _customTypeBuffer.height != buffer.height || _customTypeBuffer.pixelFormat != buffer.pixelFormat || _customTypeBuffer.dataType != targetType) {
    _customTypeBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width
                                                    height:buffer.height
                                               pixelFormat:buffer.pixelFormat
                                                  dataType:targetType
                                                     proxy:_proxy];
  }
  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = _customTypeBuffer.imageBuffer;
  
  vImage_Error error = kvImageNoError;
  switch (targetType) {
    case UINT8:
      break;
    case FLOAT32: {
      // Convert uint8 -> float32
      error = vImageConvert_Planar8toPlanarF(source,
                                             destination,
                                             1.0f,
                                             0.0f,
                                             kvImageNoFlags);
      break;
    }
    default:
      [NSException raise:@"Unknown target data type!" format:@"Data type was unknown."];
      break;
  }
  
  if (error != kvImageNoError) {
    [NSException raise:@"Resize Error" format:@"Failed to convert uint8 to float! Error: %zu", error];
  }
  
  return _customTypeBuffer;
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

  ConvertPixelFormat pixelFormat = BGRA;
  NSString* pixelFormatString = arguments[@"pixelFormat"];
  if (pixelFormatString != nil) {
    pixelFormat = parsePixelFormat(pixelFormatString);
    NSLog(@"ResizePlugin: Using target format: %@", pixelFormatString);
  } else {
    NSLog(@"ResizePlugin: No custom target format supplied.");
  }
  
  ConvertDataType dataType = UINT8;
  NSString* dataTypeString = arguments[@"dataType"];
  if (dataTypeString != nil) {
    dataType = parseDataType(dataTypeString);
    NSLog(@"ResizePlugin: Using target data type: %@", dataTypeString);
  } else {
    NSLog(@"ResizePlugin: No custom data type supplied.");
  }
  
  // TODO: Init
  FrameBuffer* result = nil;
  
  // 2. Convert from source pixel format (YUV) to a pixel format we can work with (RGB)
  FourCharCode sourceType = getFramePixelFormat(frame);
  if (sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
    // Convert YUV (4:2:0) -> ARGB_8888 first, only then we can operate in RGB layouts
    result = [self convertYUV:frame
                        toRGB:kvImageARGB8888];
  } else if (sourceType == kCVPixelFormatType_32BGRA) {
    // we're in BGRA
  } else {
    [NSException raise:@"Invalid PixelFormat" format:@"Frame has invalid Pixel Format! Disable buffer compression and 10-bit HDR."];
    return nil;
  }
    
  // 3. Resize
  result = [self resizeARGB:result
                    toWidth:targetWidth
                   toHeight:targetHeight];
  
  // 4. Convert ARGB -> ??? format
  result = [self convertARGB:result
                          to:pixelFormat];
  
  // 5. Convert UINT8 -> ??? type
  result = [self convertInt8Buffer:result
                        toDataType:dataType];
  
  // 6. Return to JS
  return result.sharedArray;
}

VISION_EXPORT_FRAME_PROCESSOR(ResizePlugin, resize);

@end
