//
//  FrameBuffer.h
//  VisionCameraResizePlugin
//
//  Created by Marc Rousavy on 24.01.24.
//  Copyright © 2023 Facebook. All rights reserved.
//

#pragma once

#import <Accelerate/Accelerate.h>
#import <Foundation/Foundation.h>
#import <VisionCamera/SharedArray.h>
#import <VisionCamera/VisionCameraProxyHolder.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ConvertPixelFormat) { RGB, ARGB, RGBA, BGR, BGRA, ABGR };

typedef NS_ENUM(NSInteger, ConvertDataType) { UINT8, FLOAT32 };

@interface FrameBuffer : NSObject

- (instancetype)initWithWidth:(size_t)width
                       height:(size_t)height
                  pixelFormat:(ConvertPixelFormat)pixelFormat
                     dataType:(ConvertDataType)dataType
                        proxy:(VisionCameraProxyHolder*)proxy;

@property(nonatomic, readonly) size_t width;
@property(nonatomic, readonly) size_t height;
@property(nonatomic, readonly) ConvertPixelFormat pixelFormat;
@property(nonatomic, readonly) ConvertDataType dataType;

@property(nonatomic, readonly) size_t channelsPerPixel;
@property(nonatomic, readonly) size_t bytesPerChannel;
@property(nonatomic, readonly) size_t bytesPerPixel;

@property(nonatomic, readonly, nonnull) const vImage_Buffer* imageBuffer;
@property(nonatomic, readonly, nonnull) SharedArray* sharedArray;

+ (size_t)getBytesForDataType:(ConvertDataType)type;
+ (size_t)getChannelsPerPixelForFormat:(ConvertPixelFormat)format;
+ (size_t)getBytesPerPixel:(ConvertPixelFormat)format withType:(ConvertDataType)type;

@end

NS_ASSUME_NONNULL_END
