#pragma once

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ResizeResult : NSObject

- (instancetype)initWithData:(void*)data size:(size_t)size;
- (nullable void*)takeData;

@property(nonatomic, readonly) size_t size;

@end

@interface ResizeProcessor : NSObject

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
                                       error:(NSError* _Nullable* _Nullable)error;

@end

NS_ASSUME_NONNULL_END
