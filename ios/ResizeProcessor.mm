#import "ResizeProcessor.h"

#import <Accelerate/Accelerate.h>
#import <UIKit/UIKit.h>
#import <memory>
#import <utility>

#import "FrameBuffer.h"

typedef NS_ENUM(NSInteger, Rotation) {
  Rotation0 = 0,
  Rotation90 = 90,
  Rotation180 = 180,
  Rotation270 = 270,
};

#define AdvancePtr(_ptr, _bytes) (__typeof__(_ptr))((uintptr_t)(_ptr) + (size_t)(_bytes))

@implementation ResizeResult {
  void* _data;
}

- (instancetype)initWithData:(void*)data size:(size_t)size {
  if (self = [super init]) {
    _data = data;
    _size = size;
  }
  return self;
}

- (void)dealloc {
  free(_data);
}

- (void*)takeData {
  void* data = _data;
  _data = nil;
  return data;
}

@end

static Rotation parseRotation(NSInteger rotation) {
  switch (rotation) {
    case 0:
      return Rotation0;
    case 90:
      return Rotation90;
    case 180:
      return Rotation180;
    case 270:
      return Rotation270;
    default:
      @throw [NSException exceptionWithName:@"Invalid Rotation"
                                     reason:[NSString stringWithFormat:@"Invalid rotation value! (%ld)", (long)rotation]
                                   userInfo:nil];
  }
}

static ConvertPixelFormat parsePixelFormat(NSInteger pixelFormat) {
  switch (pixelFormat) {
    case 0:
      return RGB;
    case 1:
      return RGBA;
    case 2:
      return ARGB;
    case 3:
      return BGRA;
    case 4:
      return BGR;
    case 5:
      return ABGR;
    default:
      @throw [NSException exceptionWithName:@"Invalid PixelFormat"
                                     reason:[NSString stringWithFormat:@"Invalid PixelFormat passed! (%ld)", (long)pixelFormat]
                                   userInfo:nil];
  }
}

static ConvertDataType parseDataType(NSInteger dataType) {
  switch (dataType) {
    case 0:
      return UINT8;
    case 1:
      return FLOAT32;
    default:
      @throw [NSException exceptionWithName:@"Invalid DataType"
                                     reason:[NSString stringWithFormat:@"Invalid DataType passed! (%ld)", (long)dataType]
                                   userInfo:nil];
  }
}

static FourCharCode getFramePixelFormat(CMSampleBufferRef sampleBuffer) {
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
  return CMFormatDescriptionGetMediaSubType(format);
}

static vImageYpCbCrType getFramevImageFormat(CMSampleBufferRef sampleBuffer) {
  FourCharCode subType = getFramePixelFormat(sampleBuffer);
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

static vImage_YpCbCrPixelRange getRange(FourCharCode pixelFormat) {
  switch (pixelFormat) {
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
      return (vImage_YpCbCrPixelRange){0, 128, 255, 255, 255, 1, 255, 0};
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
      return (vImage_YpCbCrPixelRange){16, 128, 235, 240, 235, 16, 240, 16};
    default:
      @throw [NSException exceptionWithName:@"Unknown YUV pixel format!"
                                     reason:@"Frame Pixel format is not supported in vImage_YpCbCrPixelRange!"
                                   userInfo:nil];
  }
}

@implementation ResizeProcessor {
  FrameBuffer* _argbBuffer;
  FrameBuffer* _resizeBuffer;
  FrameBuffer* _mirrorBuffer;
  FrameBuffer* _rotateBuffer;
  FrameBuffer* _convertBuffer;
  FrameBuffer* _customTypeBuffer;
  void* _tempResizeBuffer;
}

- (void)dealloc {
  free(_tempResizeBuffer);
}

- (FrameBuffer*)convertYUV:(CMSampleBufferRef)sampleBuffer toRGB:(vImageARGBType)targetType {
  vImage_Error error = kvImageNoError;

  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);

  vImage_YpCbCrPixelRange range = getRange(getFramePixelFormat(sampleBuffer));

  vImage_YpCbCrToARGB info;
  vImageYpCbCrType sourcevImageFormat = getFramevImageFormat(sampleBuffer);
  error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &info, sourcevImageFormat,
                                                        targetType, kvImageNoFlags);
  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"YUV -> RGB conversion error"
                                   reason:[NSString stringWithFormat:@"Failed to create YUV -> RGB conversion! Error: %zu", error]
                                 userInfo:nil];
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  vImage_Buffer sourceY = {.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
                           .width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
                           .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
                           .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)};
  vImage_Buffer sourceCbCr = {.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
                              .width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
                              .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
                              .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)};

  if (_argbBuffer == nil || _argbBuffer.width != width || _argbBuffer.height != height) {
    _argbBuffer = [[FrameBuffer alloc] initWithWidth:width height:height pixelFormat:ARGB dataType:UINT8];
  }
  const vImage_Buffer* destination = _argbBuffer.imageBuffer;

  error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceY, &sourceCbCr, destination, &info, nil, 255, kvImageNoFlags);
  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"YUV -> RGB conversion error"
                                   reason:[NSString stringWithFormat:@"Failed to run YUV -> RGB conversion! Error: %zu", error]
                                 userInfo:nil];
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  return _argbBuffer;
}

- (FrameBuffer*)convertARGB:(FrameBuffer*)buffer to:(ConvertPixelFormat)destinationFormat {
  vImage_Error error = kvImageNoError;
  Pixel_8888 backgroundColor{0, 0, 0, 255};

  FrameBuffer* destinationBuffer = buffer;
  size_t targetBytesPerPixel = [FrameBuffer getBytesPerPixel:destinationFormat withType:UINT8];
  if (buffer.bytesPerPixel != targetBytesPerPixel) {
    if (_convertBuffer == nil || _convertBuffer.width != buffer.width || _convertBuffer.height != buffer.height ||
        _convertBuffer.pixelFormat != destinationFormat) {
      _convertBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width height:buffer.height pixelFormat:destinationFormat dataType:UINT8];
    }
    destinationBuffer = _convertBuffer;
  }

  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = destinationBuffer.imageBuffer;

  switch (destinationFormat) {
    case RGB:
      error = vImageFlatten_ARGB8888ToRGB888(source, destination, backgroundColor, false, kvImageNoFlags);
      break;
    case BGR: {
      error = vImageFlatten_ARGB8888ToRGB888(source, destination, backgroundColor, false, kvImageNoFlags);
      uint8_t permuteMap[4] = {2, 1, 0};
      error = vImagePermuteChannels_RGB888(destination, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ARGB:
      break;
    case RGBA: {
      uint8_t permuteMap[4] = {1, 2, 3, 0};
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case BGRA: {
      uint8_t permuteMap[4] = {3, 2, 1, 0};
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
    case ABGR: {
      uint8_t permuteMap[4] = {0, 3, 2, 1};
      error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
      break;
    }
  }

  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"Convert Error"
                                   reason:[NSString stringWithFormat:@"Failed to convert ARGB buffer! Error: %zu", error]
                                 userInfo:nil];
  }

  return destinationBuffer;
}

- (FrameBuffer*)convertFrameToARGB:(CMSampleBufferRef)sampleBuffer {
  CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
  size_t width = CVPixelBufferGetWidth(pixelBuffer);
  size_t height = CVPixelBufferGetHeight(pixelBuffer);
  size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

  if (_argbBuffer == nil || _argbBuffer.width != width || _argbBuffer.height != height) {
    _argbBuffer = [[FrameBuffer alloc] initWithWidth:width height:height pixelFormat:ARGB dataType:UINT8];
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  vImage_Buffer input{
      .data = CVPixelBufferGetBaseAddress(pixelBuffer), .width = width, .height = height, .rowBytes = bytesPerRow};
  const vImage_Buffer* destination = _argbBuffer.imageBuffer;

  uint8_t permuteMap[4] = {3, 2, 1, 0};
  vImage_Error error = vImagePermuteChannels_ARGB8888(&input, destination, permuteMap, kvImageNoFlags);
  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"RGB Conversion Error"
                                   reason:[NSString stringWithFormat:@"Failed to convert Frame to ARGB! Error: %zu", error]
                                 userInfo:nil];
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

  return _argbBuffer;
}

- (FrameBuffer*)resizeARGB:(FrameBuffer*)buffer crop:(CGRect)crop scale:(CGSize)scale {
  CGFloat cropWidth = crop.size.width;
  CGFloat cropHeight = crop.size.height;
  CGFloat cropX = crop.origin.x;
  CGFloat cropY = crop.origin.y;
  CGFloat scaleWidth = scale.width;
  CGFloat scaleHeight = scale.height;

  if (buffer.width == cropWidth && buffer.height == cropHeight && buffer.width == scaleWidth && buffer.height == scaleHeight &&
      cropX == 0 && cropY == 0) {
    return buffer;
  }

  if (_resizeBuffer == nil || _resizeBuffer.width != scaleWidth || _resizeBuffer.height != scaleHeight) {
    _resizeBuffer = [[FrameBuffer alloc] initWithWidth:scaleWidth height:scaleHeight pixelFormat:ARGB dataType:UINT8];
    free(_tempResizeBuffer);
    _tempResizeBuffer = nil;
  }
  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = _resizeBuffer.imageBuffer;

  if (_tempResizeBuffer == nil) {
    size_t tempBufferSize = vImageScale_ARGB8888(source, destination, nil, kvImageGetTempBufferSize);
    if (tempBufferSize > 0) {
      free(_tempResizeBuffer);
      _tempResizeBuffer = malloc(tempBufferSize);
    }
  }

  vImage_Buffer cropped = (vImage_Buffer){.data = AdvancePtr(source->data, cropY * source->rowBytes + cropX * buffer.bytesPerPixel),
                                          .height = (unsigned long)cropHeight,
                                          .width = (unsigned long)cropWidth,
                                          .rowBytes = source->rowBytes};
  source = &cropped;

  vImage_Error error = vImageScale_ARGB8888(source, destination, _tempResizeBuffer, kvImageNoFlags);
  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"Resize Error"
                                   reason:[NSString stringWithFormat:@"Failed to resize ARGB buffer! Error: %zu", error]
                                 userInfo:nil];
  }

  return _resizeBuffer;
}

- (FrameBuffer*)convertInt8Buffer:(FrameBuffer*)buffer toDataType:(ConvertDataType)targetType {
  if (buffer.dataType == targetType) {
    return buffer;
  }

  if (_customTypeBuffer == nil || _customTypeBuffer.width != buffer.width || _customTypeBuffer.height != buffer.height ||
      _customTypeBuffer.pixelFormat != buffer.pixelFormat || _customTypeBuffer.dataType != targetType) {
    _customTypeBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width height:buffer.height pixelFormat:buffer.pixelFormat dataType:targetType];
  }
  const vImage_Buffer* source = buffer.imageBuffer;
  const vImage_Buffer* destination = _customTypeBuffer.imageBuffer;

  switch (targetType) {
    case UINT8:
      break;
    case FLOAT32: {
      uint8_t* input = (uint8_t*)source->data;
      float* output = (float*)destination->data;
      size_t numBytes = source->height * source->rowBytes;
      float scale = 1.0f / 255.0f;

      vDSP_vfltu8(input, 1, output, 1, numBytes);
      vDSP_vsmul(output, 1, &scale, output, 1, numBytes);
      break;
    }
    default:
      @throw [NSException exceptionWithName:@"Unknown target data type!" reason:@"Data type was unknown" userInfo:nil];
  }

  return _customTypeBuffer;
}

- (FrameBuffer*)mirrorARGBBuffer:(FrameBuffer*)buffer mirror:(BOOL)mirror {
  if (!mirror) {
    return buffer;
  }

  if (_mirrorBuffer == nil || _mirrorBuffer.width != buffer.width || _mirrorBuffer.height != buffer.height) {
    _mirrorBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width height:buffer.height pixelFormat:buffer.pixelFormat dataType:buffer.dataType];
  }

  vImage_Buffer src = *buffer.imageBuffer;
  vImage_Buffer dest = *_mirrorBuffer.imageBuffer;

  vImage_Error error = vImageHorizontalReflect_ARGB8888(&src, &dest, kvImageNoFlags);
  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"Mirror Error"
                                   reason:[NSString stringWithFormat:@"Failed to mirror ARGB buffer! Error: %zu", error]
                                 userInfo:nil];
  }

  return _mirrorBuffer;
}

- (FrameBuffer*)rotateARGBBuffer:(FrameBuffer*)buffer rotation:(Rotation)rotation {
  if (rotation == Rotation0) {
    return buffer;
  }

  int rotatedWidth = (int)buffer.width;
  int rotatedHeight = (int)buffer.height;
  if (rotation == Rotation90 || rotation == Rotation270) {
    int temp = rotatedWidth;
    rotatedWidth = rotatedHeight;
    rotatedHeight = temp;
  }

  if (_rotateBuffer == nil || _rotateBuffer.width != (size_t)rotatedWidth || _rotateBuffer.height != (size_t)rotatedHeight) {
    _rotateBuffer = [[FrameBuffer alloc] initWithWidth:(size_t)rotatedWidth
                                                height:(size_t)rotatedHeight
                                           pixelFormat:buffer.pixelFormat
                                              dataType:buffer.dataType];
  }

  const vImage_Buffer* src = buffer.imageBuffer;
  const vImage_Buffer* dest = _rotateBuffer.imageBuffer;

  vImage_Error error = kvImageNoError;
  Pixel_8888 backgroundColor = {0, 0, 0, 0};
  switch (rotation) {
    case Rotation90:
      error = vImageRotate90_ARGB8888(src, dest, kRotate90DegreesClockwise, backgroundColor, kvImageNoFlags);
      break;
    case Rotation180:
      error = vImageRotate90_ARGB8888(src, dest, kRotate180DegreesClockwise, backgroundColor, kvImageNoFlags);
      break;
    case Rotation270:
      error = vImageRotate90_ARGB8888(src, dest, kRotate270DegreesClockwise, backgroundColor, kvImageNoFlags);
      break;
    default:
      @throw [NSException exceptionWithName:@"Invalid Rotation"
                                     reason:[NSString stringWithFormat:@"Invalid Rotation! (%zu)", (size_t)rotation]
                                   userInfo:nil];
  }

  if (error != kvImageNoError) {
    @throw [NSException exceptionWithName:@"Rotation Error"
                                   reason:[NSString stringWithFormat:@"Failed to rotate ARGB buffer! Error %ld", error]
                                 userInfo:nil];
  }

  return _rotateBuffer;
}

- (ResizeResult*)copyResult:(FrameBuffer*)buffer {
  void* copy = malloc(buffer.size);
  if (copy == nil) {
    @throw [NSException exceptionWithName:@"ResizeResult allocation error"
                                   reason:[NSString stringWithFormat:@"Failed to allocate %zu bytes", buffer.size]
                                 userInfo:nil];
  }
  memcpy(copy, buffer.data, buffer.size);
  return [[ResizeResult alloc] initWithData:copy size:buffer.size];
}

- (nullable ResizeResult*)resizeSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                       cropX:(size_t)cropX
                                       cropY:(size_t)cropY
                                   cropWidth:(size_t)cropWidth
                                  cropHeight:(size_t)cropHeight
                                  scaleWidth:(size_t)scaleWidth
                                 scaleHeight:(size_t)scaleHeight
                                    rotation:(NSInteger)rotation
                                      mirror:(BOOL)mirror
                                 pixelFormat:(NSInteger)pixelFormat
                                    dataType:(NSInteger)dataType
                                       error:(NSError* _Nullable* _Nullable)error {
  @try {
    if (sampleBuffer == nil) {
      @throw [NSException exceptionWithName:@"Invalid sample buffer" reason:@"SampleBuffer is null." userInfo:nil];
    }

    ConvertPixelFormat targetPixelFormat = parsePixelFormat(pixelFormat);
    ConvertDataType targetDataType = parseDataType(dataType);
    Rotation targetRotation = parseRotation(rotation);

    FrameBuffer* result = nil;
    FourCharCode sourceType = getFramePixelFormat(sampleBuffer);
    if (sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
      result = [self convertYUV:sampleBuffer toRGB:kvImageARGB8888];
    } else if (sourceType == kCVPixelFormatType_32BGRA) {
      result = [self convertFrameToARGB:sampleBuffer];
    } else {
      @throw [NSException exceptionWithName:@"Invalid PixelFormat"
                                     reason:@"Frame has invalid Pixel Format! Disable buffer compression and 10-bit HDR."
                                   userInfo:nil];
    }

    CGRect cropRect = CGRectMake((CGFloat)cropX, (CGFloat)cropY, (CGFloat)cropWidth, (CGFloat)cropHeight);
    CGSize scaleSize = CGSizeMake((CGFloat)scaleWidth, (CGFloat)scaleHeight);
    result = [self resizeARGB:result crop:cropRect scale:scaleSize];
    result = [self rotateARGBBuffer:result rotation:targetRotation];
    result = [self mirrorARGBBuffer:result mirror:mirror];
    result = [self convertARGB:result to:targetPixelFormat];
    result = [self convertInt8Buffer:result toDataType:targetDataType];
    return [self copyResult:result];
  } @catch (NSException* exception) {
    if (error != nil) {
      *error = [NSError errorWithDomain:@"VisionCameraResizePlugin"
                                   code:1
                               userInfo:@{NSLocalizedDescriptionKey : exception.reason ?: @"Unknown ResizeProcessor error."}];
    }
    return nil;
  }
}

@end
