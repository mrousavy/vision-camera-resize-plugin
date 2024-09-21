//
//  ResizePlugin.mm
//  VisionCameraResizePlugin
//
//  Created by Marc Rousavy on 23.09.23.
//  Copyright © 2023 Facebook. All rights reserved.
//

#import <VisionCamera/Frame.h>
#import <VisionCamera/FrameProcessorPlugin.h>
#import <VisionCamera/FrameProcessorPluginRegistry.h>
#import <VisionCamera/SharedArray.h>

#import <Accelerate/Accelerate.h>
#import <memory>
#import <utility>

#import "FrameBuffer.h"

typedef NS_ENUM(NSInteger, Rotation) { Rotation0 = 0, Rotation90 = 90, Rotation180 = 180, Rotation270 = 270 };

@interface ResizePlugin : FrameProcessorPlugin
@end

#define AdvancePtr(_ptr, _bytes) (__typeof__(_ptr))((uintptr_t)(_ptr) + (size_t)(_bytes))

@implementation ResizePlugin {
    // 1. ??? (?x?) -> ARGB (?x?)
    FrameBuffer* _argbBuffer;
    // 2. ARGB (?x?) -> ARGB (!x!)
    FrameBuffer* _resizeBuffer;
    FrameBuffer* _mirrorBuffer;
    FrameBuffer* _rotateBuffer;
    // 3. ARGB (!x!) -> !!!! (!x!)
    FrameBuffer* _convertBuffer;
    // 3. uint8 -> other type (e.g. float32) if needed
    FrameBuffer* _customTypeBuffer;
    
    // Cache
    void* _tempResizeBuffer;
    VisionCameraProxyHolder* _proxy;
}

- (instancetype)initWithProxy:(VisionCameraProxyHolder*)proxy withOptions:(NSDictionary*)options {
    if (self = [super initWithProxy:proxy withOptions:options]) {
        _proxy = proxy;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"Deallocating ResizePlugin...");
    free(_tempResizeBuffer);
}

Rotation parseRotation(NSString* rotationString) {
    if ([rotationString isEqualToString:@"0deg"]) {
        return Rotation0;
    } else if ([rotationString isEqualToString:@"90deg"]) {
        return Rotation90;
    } else if ([rotationString isEqualToString:@"180deg"]) {
        return Rotation180;
    } else if ([rotationString isEqualToString:@"270deg"]) {
        return Rotation270;
    } else {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Invalid Rotation"
                                       reason:[NSString stringWithFormat:@"Invalid rotation value! (%@)", rotationString]
                                     userInfo:nil];
    }
}

ConvertPixelFormat parsePixelFormat(NSString* pixelFormat) {
    if ([pixelFormat isEqualToString:@"rgb"]) {
        return RGB;
    } else if ([pixelFormat isEqualToString:@"rgba"]) {
        return RGBA;
    } else if ([pixelFormat isEqualToString:@"argb"]) {
        return ARGB;
    } else if ([pixelFormat isEqualToString:@"bgra"]) {
        return BGRA;
    } else if ([pixelFormat isEqualToString:@"bgr"]) {
        return BGR;
    } else if ([pixelFormat isEqualToString:@"abgr"]) {
        return ABGR;
    } else {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Invalid PixelFormat"
                                       reason:[NSString stringWithFormat:@"Invalid PixelFormat passed! (%@)", pixelFormat]
                                     userInfo:nil];
    }
}

ConvertDataType parseDataType(NSString* dataType) {
    if ([dataType isEqualToString:@"uint8"]) {
        return UINT8;
    } else if ([dataType isEqualToString:@"float32"]) {
        return FLOAT32;
    } else {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Invalid DataType"
                                       reason:[NSString stringWithFormat:@"Invalid DataType passed! (%@)", dataType]
                                     userInfo:nil];
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

vImage_YpCbCrPixelRange getRange(FourCharCode pixelFormat) {
    // Values are from vImage_Types.h::vImage_YpCbCrPixelRange
    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            return (vImage_YpCbCrPixelRange){0, 128, 255, 255, 255, 1, 255, 0};
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return (vImage_YpCbCrPixelRange){16, 128, 235, 240, 235, 16, 240, 16};
        default:
            [[unlikely]];
            @throw [NSException exceptionWithName:@"Unknown YUV pixel format!"
                                           reason:@"Frame Pixel format is not supported in vImage_YpCbCrPixelRange!"
                                         userInfo:nil];
    }
}

- (FrameBuffer*)convertYUV:(Frame*)frame toRGB:(vImageARGBType)targetType {
    NSLog(@"Converting YUV Frame to RGB...");
    vImage_Error error = kvImageNoError;
    
    vImage_YpCbCrPixelRange range = getRange(getFramePixelFormat(frame));
    
    vImage_YpCbCrToARGB info;
    vImageYpCbCrType sourcevImageFormat = getFramevImageFormat(frame);
    error = vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &range, &info, sourcevImageFormat,
                                                          targetType, kvImageNoFlags);
    if (error != kvImageNoError) {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"YUV -> RGB conversion error"
                                       reason:[NSString stringWithFormat:@"Failed to create YUV -> RGB conversion! Error: %zu", error]
                                     userInfo:nil];
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    vImage_Buffer sourceY = {.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
            .width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0),
            .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0),
        .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)};
    vImage_Buffer sourceCbCr = {.data = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1),
            .width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1),
            .height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1),
        .rowBytes = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)};
    
    if (_argbBuffer == nil || _argbBuffer.width != frame.width || _argbBuffer.height != frame.height) {
        _argbBuffer = [[FrameBuffer alloc] initWithWidth:frame.width height:frame.height pixelFormat:ARGB dataType:UINT8 proxy:_proxy];
    }
    const vImage_Buffer* destination = _argbBuffer.imageBuffer;
    
    error = vImageConvert_420Yp8_CbCr8ToARGB8888(&sourceY, &sourceCbCr, destination, &info, nil, 255, kvImageNoFlags);
    if (error != kvImageNoError) {
        [[unlikely]];
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
    
    // If possible, do all conversions in-memory.
    FrameBuffer* destinationBuffer = buffer;
    
    size_t targetBytesPerPixel = [FrameBuffer getBytesPerPixel:destinationFormat withType:UINT8];
    if (buffer.bytesPerPixel != targetBytesPerPixel) {
        // The bytes per pixel are not the same, so we need an intermediate array allocation.
        if (_convertBuffer == nil || _convertBuffer.width != buffer.width || _convertBuffer.height != buffer.height ||
            _convertBuffer.pixelFormat != destinationFormat) {
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
            uint8_t permuteMap[4] = {2, 1, 0};
            error = vImagePermuteChannels_RGB888(destination, destination, permuteMap, kvImageNoFlags);
            break;
        }
        case ARGB: {
            // We are already in ARGB_8. No need to do anything.
            break;
        }
        case RGBA: {
            NSLog(@"Converting ARGB_8 Frame to RGBA_8...");
            uint8_t permuteMap[4] = {1, 2, 3, 0};
            error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
            break;
        }
        case BGRA: {
            NSLog(@"Converting ARGB_8 Frame to BGRA_8...");
            uint8_t permuteMap[4] = {3, 2, 1, 0};
            error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
            break;
        }
        case ABGR: {
            NSLog(@"Converting ARGB_8 Frame to ABGR_8...");
            uint8_t permuteMap[4] = {0, 3, 2, 1};
            error = vImagePermuteChannels_ARGB8888(source, destination, permuteMap, kvImageNoFlags);
            break;
        }
    }
    
    if (error != kvImageNoError) {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"RGB Conversion Error"
                                       reason:[NSString stringWithFormat:@"Failed to convert RGB layout! Error: %zu", error]
                                     userInfo:nil];
    }
    
    return destinationBuffer;
}

- (FrameBuffer*)convertFrameToARGB:(Frame*)frame {
    NSLog(@"Converting BGRA_8 Frame to ARGB_8...");
    
    if (_argbBuffer == nil || _argbBuffer.width != frame.width || _argbBuffer.height != frame.height) {
        _argbBuffer = [[FrameBuffer alloc] initWithWidth:frame.width height:frame.height pixelFormat:ARGB dataType:UINT8 proxy:_proxy];
    }
    
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(frame.buffer);
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    vImage_Buffer input{
        .data = CVPixelBufferGetBaseAddress(pixelBuffer), .width = frame.width, .height = frame.height, .rowBytes = frame.bytesPerRow};
    const vImage_Buffer* destination = _argbBuffer.imageBuffer;
    
    uint8_t permuteMap[4] = {3, 2, 1, 0};
    vImage_Error error = vImagePermuteChannels_ARGB8888(&input, destination, permuteMap, kvImageNoFlags);
    if (error != kvImageNoError) {
        [[unlikely]];
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
        // We are already in the target size.
        NSLog(@"Skipping resize, buffer is already desired size (%f x %f)...", scaleWidth, scaleHeight);
        return buffer;
    }
    
    NSLog(@"Resizing ARGB_8 Frame to %f x %f...", scaleWidth, scaleHeight);
    
    if (_resizeBuffer == nil || _resizeBuffer.width != scaleWidth || _resizeBuffer.height != scaleHeight) {
        _resizeBuffer = [[FrameBuffer alloc] initWithWidth:scaleWidth height:scaleHeight pixelFormat:ARGB dataType:UINT8 proxy:_proxy];
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
    
    // Crop
    
    vImage_Buffer cropped;
    bool should_free_source = false;
    
    // Check if cropped rect is fully inside the original image
    if (cropX < 0 || cropY < 0 || cropX + cropWidth > buffer.width || cropY + cropHeight > buffer.height) {
        NSLog(@"Warning: Crop rectangle is not fully inside the original image. Adjusting...");
        
        // Adjust crop rectangle to fit within the image bounds
        CGFloat adjustedCropX = MAX(0, cropX);
        CGFloat adjustedCropY = MAX(0, cropY);
        CGFloat adjustedCropWidth = MIN(cropWidth - (adjustedCropX - cropX), buffer.width - adjustedCropX);
        CGFloat adjustedCropHeight = MIN(cropHeight - (adjustedCropY - cropY), buffer.height - adjustedCropY);
        
        // Allocate new buffer for cropped image
        size_t rowBytes = cropWidth * buffer.bytesPerPixel;
        size_t croppedBufferSize = rowBytes * cropHeight;
        void* newBuffer = malloc(croppedBufferSize);
        if (newBuffer == NULL) {
            @throw [NSException exceptionWithName:@"Memory Allocation Error"
                                           reason:@"Failed to allocate memory for cropped buffer"
                                         userInfo:nil];
        }
        
        // vImage_Buffer 
        cropped = (vImage_Buffer){
            .data = AdvancePtr(source->data, (size_t)(adjustedCropY) * source->rowBytes + (size_t)(adjustedCropX) * buffer.bytesPerPixel),
            .height = (vImagePixelCount)adjustedCropHeight,
            .width = (vImagePixelCount)adjustedCropWidth,
            .rowBytes = source->rowBytes
        };
        
        vImage_Buffer dest = (vImage_Buffer){
            .data = AdvancePtr(newBuffer, (size_t)((adjustedCropY - cropY) * rowBytes + (adjustedCropX - cropX) * buffer.bytesPerPixel)),
            .height = (vImagePixelCount)adjustedCropHeight,
            .width = (vImagePixelCount)adjustedCropWidth,
            .rowBytes = rowBytes
        };
        
        vImage_Buffer croppedWithPadding = (vImage_Buffer){
            .data = newBuffer,
            .height = (vImagePixelCount)cropHeight,
            .width = (vImagePixelCount)cropWidth,
            .rowBytes = rowBytes
        };
        
        // Copy the cropped portion of the source image
        uint8_t black[4] = {255, 0, 0, 0};
        vImageBufferFill_ARGB8888(&croppedWithPadding, black, kvImageNoFlags);
        vImage_Error copyError = vImageCopyBuffer(&cropped, &dest, buffer.bytesPerPixel, kvImageNoFlags);
        if (copyError != kvImageNoError) {
            free(newBuffer);
            @throw [NSException exceptionWithName:@"Image Copy Error"
                                           reason:[NSString stringWithFormat:@"Failed to copy cropped image. Error: %zu", copyError]
                                         userInfo:nil];
        }
        
        source = &croppedWithPadding;
        should_free_source = true;
    } else {
        cropped = (vImage_Buffer){.data = AdvancePtr(source->data, cropY * source->rowBytes + cropX * buffer.bytesPerPixel),
                .height = (unsigned long)cropHeight,
                .width = (unsigned long)cropWidth,
            .rowBytes = source->rowBytes};
        source = &cropped;
    }
    
    
    // Resize
    vImage_Error error = vImageScale_ARGB8888(source, destination, _tempResizeBuffer, kvImageNoFlags);
    if(should_free_source) {
        free(source->data);
    }
    if (error != kvImageNoError) {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Resize Error"
                                       reason:[NSString stringWithFormat:@"Failed to resize ARGB buffer! Error: %zu", error]
                                     userInfo:nil];
    }
    
    return _resizeBuffer;
}

- (FrameBuffer*)convertInt8Buffer:(FrameBuffer*)buffer toDataType:(ConvertDataType)targetType {
    if (buffer.dataType == targetType) {
        // we are already in the target type
        return buffer;
    }
    
    NSLog(@"Converting uint8 (%zu) buffer to target type (%zu)...", buffer.dataType, targetType);
    
    if (_customTypeBuffer == nil || _customTypeBuffer.width != buffer.width || _customTypeBuffer.height != buffer.height ||
        _customTypeBuffer.pixelFormat != buffer.pixelFormat || _customTypeBuffer.dataType != targetType) {
        _customTypeBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width
                                                        height:buffer.height
                                                   pixelFormat:buffer.pixelFormat
                                                      dataType:targetType
                                                         proxy:_proxy];
    }
    const vImage_Buffer* source = buffer.imageBuffer;
    const vImage_Buffer* destination = _customTypeBuffer.imageBuffer;
    
    switch (targetType) {
        case UINT8:
            break;
        case FLOAT32: {
            // Convert uint8 -> float32
            uint8_t* input = (uint8_t*)source->data;
            float* output = (float*)destination->data;
            size_t numBytes = source->height * source->rowBytes;
            float scale = 1.0f / 255.0f;
            
            vDSP_vfltu8(input, 1, output, 1, numBytes);
            vDSP_vsmul(output, 1, &scale, output, 1, numBytes);
            break;
        }
        default:
            [[unlikely]];
            @throw [NSException exceptionWithName:@"Unknown target data type!" reason:@"Data type was unknown" userInfo:nil];
    }
    
    return _customTypeBuffer;
}

- (FrameBuffer*)mirrorARGBBuffer:(FrameBuffer*)buffer mirror:(BOOL)mirror {
    
    if (!mirror) {
        return buffer;
    }
    
    NSLog(@"Mirroring ARGB buffer...");
    
    if (_mirrorBuffer == nil || _mirrorBuffer.width != buffer.width || _mirrorBuffer.height != buffer.height) {
        _mirrorBuffer = [[FrameBuffer alloc] initWithWidth:buffer.width
                                                    height:buffer.height
                                               pixelFormat:buffer.pixelFormat
                                                  dataType:buffer.dataType
                                                     proxy:_proxy];
    }
    
    vImage_Buffer src = *buffer.imageBuffer;
    vImage_Buffer dest = *_mirrorBuffer.imageBuffer;
    
    vImage_Error error = vImageHorizontalReflect_ARGB8888(&src, &dest, kvImageNoFlags);
    if (error != kvImageNoError) {
        [[unlikely]];
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
    
    NSLog(@"Rotating ARGB buffer...");
    
    int rotatedWidth = buffer.width;
    int rotatedHeight = buffer.height;
    if (rotation == Rotation90 || rotation == Rotation270) {
        int temp = rotatedWidth;
        rotatedWidth = rotatedHeight;
        rotatedHeight = temp;
    }
    
    if (_rotateBuffer == nil || _rotateBuffer.width != rotatedWidth || _rotateBuffer.height != rotatedHeight) {
        _rotateBuffer = [[FrameBuffer alloc] initWithWidth:rotatedWidth
                                                    height:rotatedHeight
                                               pixelFormat:buffer.pixelFormat
                                                  dataType:buffer.dataType
                                                     proxy:_proxy];
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
            [[unlikely]];
            @throw [NSException exceptionWithName:@"Invalid Rotation"
                                           reason:[NSString stringWithFormat:@"Invalid Rotation! (%zu)", rotation]
                                         userInfo:nil];
    }
    
    if (error != kvImageNoError) {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Rotation Error"
                                       reason:[NSString stringWithFormat:@"Failed to rotate ARGB buffer! Error %ld", error]
                                     userInfo:nil];
    }
    
    return _rotateBuffer;
}

// Used only for debugging/inspecting the Image.
- (UIImage*)bufferToImage:(FrameBuffer*)buffer {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(buffer.sharedArray.data, buffer.width, buffer.height,
                                                       buffer.bytesPerChannel * 8,          // bit per component
                                                       buffer.width * buffer.bytesPerPixel, // bytes per row
                                                       colorSpace, kCGImageAlphaNoneSkipLast);
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    
    UIImage* image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);
    
    return image;
}

- (id)callback:(Frame*)frame withArguments:(NSDictionary*)arguments {
    
    // 1. Parse inputs
    double scaleWidth = (double)frame.width;
    double scaleHeight = (double)frame.height;
    NSDictionary* scale = arguments[@"scale"];
    if (scale != nil) {
        scaleWidth = ((NSNumber*)scale[@"width"]).doubleValue;
        scaleHeight = ((NSNumber*)scale[@"height"]).doubleValue;
        NSLog(@"ResizePlugin: Scaling to %f x %f.", scaleWidth, scaleHeight);
    } else {
        NSLog(@"ResizePlugin: No custom scale supplied.");
    }
    
    NSString* rotationString = arguments[@"rotation"];
    Rotation rotation;
    if (rotationString != nil) {
        rotation = parseRotation(rotationString);
        NSLog(@"ResizePlugin: Rotation: %ld", (long)rotation);
    } else {
        rotation = Rotation0;
        NSLog(@"ResizePlugin: Rotation not specified, defaulting to: %ld", (long)rotation);
    }
    
    NSNumber* mirrorParam = arguments[@"mirror"];
    BOOL mirror = NO;
    if (mirrorParam != nil) {
        mirror = [mirrorParam boolValue];
    }
    NSLog(@"ResizePlugin: Mirror: %@", mirror ? @"YES" : @"NO");
    
    double cropWidth = (double)frame.width;
    double cropHeight = (double)frame.height;
    double cropX = 0;
    double cropY = 0;
    NSDictionary* crop = arguments[@"crop"];
    if (crop != nil) {
        cropWidth = ((NSNumber*)crop[@"width"]).doubleValue;
        cropHeight = ((NSNumber*)crop[@"height"]).doubleValue;
        cropX = ((NSNumber*)crop[@"x"]).doubleValue;
        cropY = ((NSNumber*)crop[@"y"]).doubleValue;
        NSLog(@"ResizePlugin: Cropping to %f x %f, at (%f, %f)", cropWidth, cropHeight, cropX, cropY);
    } else {
        if (scale != nil) {
            double aspectRatio = (double)frame.width / (double)frame.height;
            double targetAspectRatio = scaleWidth / scaleHeight;
            
            if (aspectRatio > targetAspectRatio) {
                // 1920x1080
                cropWidth = frame.height * targetAspectRatio;
                cropHeight = frame.height;
            } else {
                // 1080x1920
                cropWidth = frame.width;
                cropHeight = frame.width / targetAspectRatio;
            }
            cropX = (frame.width / 2) - (cropWidth / 2);
            cropY = (frame.height / 2) - (cropHeight / 2);
            NSLog(@"ResizePlugin: Cropping to %f x %f at (%f, %f).", cropWidth, cropHeight, cropX, cropY);
        } else {
            NSLog(@"ResizePlugin: Both scale and crop are nil, using Frame's original dimensions.");
        }
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
    
    FrameBuffer* result = nil;
    
    // 2. Convert from source pixel format (YUV) to a pixel format we can work with (RGB)
    FourCharCode sourceType = getFramePixelFormat(frame);
    if (sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || sourceType == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
        // Convert YUV (4:2:0) -> ARGB_8888 first, only then we can operate in RGB layouts
        result = [self convertYUV:frame toRGB:kvImageARGB8888];
    } else if (sourceType == kCVPixelFormatType_32BGRA) {
        // Convert BGRA -> ARGB_8888 first, only then we can operate in RGB layouts
        result = [self convertFrameToARGB:frame];
    } else {
        [[unlikely]];
        @throw [NSException exceptionWithName:@"Invalid PixelFormat"
                                       reason:@"Frame has invalid Pixel Format! Disable buffer compression and 10-bit HDR."
                                     userInfo:nil];
    }
    
    // 3. Resize
    CGRect cropRect = CGRectMake(cropX, cropY, cropWidth, cropHeight);
    CGSize scaleSize = CGSizeMake(scaleWidth, scaleHeight);
    result = [self resizeARGB:result crop:cropRect scale:scaleSize];
    
    // 4. Rotate
    result = [self rotateARGBBuffer:result rotation:rotation];
    
    // 5. Mirror
    result = [self mirrorARGBBuffer:result mirror:mirror];
    
    // 6. Convert ARGB -> ??? format
    result = [self convertARGB:result to:pixelFormat];
    
    // 7. Convert UINT8 -> ??? type
    result = [self convertInt8Buffer:result toDataType:dataType];
    
    // 8. Return to JS
    return result.sharedArray;
}

VISION_EXPORT_FRAME_PROCESSOR(ResizePlugin, resize);

@end
