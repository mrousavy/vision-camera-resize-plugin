//
// Created by Marc Rousavy on 25.01.24
//

#include "ResizePlugin.h"
#include <android/log.h>
#include <fbjni/fbjni.h>
#include <jni.h>
#include "libyuv.h"
#include <media/NdkImage.h>

namespace vision {

using namespace facebook;

void ResizePlugin::registerNatives() {
  registerHybrid({
      makeNativeMethod("initHybrid", ResizePlugin::initHybrid),
      makeNativeMethod("resize", ResizePlugin::resize),
  });
}

ResizePlugin::ResizePlugin(const jni::alias_ref<jhybridobject>& javaThis) {
  _javaThis = jni::make_global(javaThis);
}

int getChannelCount(PixelFormat pixelFormat) {
  switch (pixelFormat) {
    case RGB:
    case BGR:
      return 3;
    case ARGB:
    case RGBA:
    case BGRA:
    case ABGR:
      return 4;
  }
}

int getBytesPerChannel(DataType type) {
  switch (type) {
    case UINT8:
      return sizeof(uint8_t);
    case FLOAT32:
      return sizeof(float_t);
  }
}

int getBytesPerPixel(PixelFormat pixelFormat, DataType type) {
  return getChannelCount(pixelFormat) * getBytesPerChannel(type);
}

int FrameBuffer::getPixelStride() {
  return getBytesPerPixel(pixelFormat, dataType);
}

int FrameBuffer::getRowStride() {
  return width * getPixelStride();
}

uint8_t* FrameBuffer::data() {
  return buffer->getDirectBytes();
}

FrameBuffer ResizePlugin::imageToFrameBuffer(alias_ref<vision::JImage> image) {
  jni::local_ref<JArrayClass<JImagePlane>> planes = image->getPlanes();

  jni::local_ref<JImagePlane> yPlane = planes->getElement(0);
  jni::local_ref<JByteBuffer> yBuffer = yPlane->getBuffer();
  jni::local_ref<JImagePlane> uPlane = planes->getElement(1);
  jni::local_ref<JByteBuffer> uBuffer = uPlane->getBuffer();
  jni::local_ref<JImagePlane> vPlane = planes->getElement(2);
  jni::local_ref<JByteBuffer> vBuffer = vPlane->getBuffer();

  size_t uvPixelStride = uPlane->getPixelStride();
  if (uPlane->getPixelStride() != vPlane->getPixelStride()) {
    throw std::runtime_error("U and V planes do not have the same pixel stride! Are you sure this is a 4:2:0 YUV format?");
  }

  int width = image->getWidth();
  int height = image->getHeight();

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t argbSize = width * height * channels * channelSize;
  if (_argbBuffer == nullptr || _argbBuffer->getDirectSize() != argbSize) {
    __android_log_print(ANDROID_LOG_INFO, TAG, "Allocating %zu ARGB ByteBuffer...", argbSize);
    jni::local_ref<JByteBuffer> buffer = JByteBuffer::allocateDirect(argbSize);
    _argbBuffer = jni::make_global(buffer);
  }
  auto destination = _argbBuffer->getDirectBytes();

  // 1. Convert from YUV -> ARGB
  int result = libyuv::Android420ToARGB(yBuffer->getDirectBytes(), yPlane->getRowStride(),
                                        uBuffer->getDirectBytes(), uPlane->getRowStride(),
                                        vBuffer->getDirectBytes(), vPlane->getRowStride(),
                                        uvPixelStride,
                                        destination, width * channels * channelSize,
                                        width, height);

  if (result != 0) {
    throw std::runtime_error("Failed to convert YUV 4:2:0 to ARGB! Error: " + std::to_string(result));
  }

  return (FrameBuffer) {
    .width = width,
    .height = height,
    .pixelFormat = PixelFormat::ARGB,
    .dataType = DataType::UINT8,
    .buffer = _argbBuffer,
  };
}

FrameBuffer ResizePlugin::convertARGBBufferTo(FrameBuffer frameBuffer, PixelFormat pixelFormat) {
  if (frameBuffer.pixelFormat == pixelFormat) {
    // Already in the correct format.
    return frameBuffer;
  }

  size_t bytesPerPixel = getBytesPerPixel(pixelFormat, frameBuffer.dataType);
  size_t targetBufferSize = frameBuffer.width * frameBuffer.height * bytesPerPixel;
  if (_customFormatBuffer == nullptr || _customFormatBuffer->getDirectSize() != targetBufferSize) {
    __android_log_print(ANDROID_LOG_INFO, TAG, "Allocating %zu ByteBuffer with custom Format...", targetBufferSize);
    jni::local_ref<JByteBuffer> buffer = JByteBuffer::allocateDirect(targetBufferSize);
    _customFormatBuffer = jni::make_global(buffer);
  }
  FrameBuffer destination = {
      .width = frameBuffer.width,
      .height = frameBuffer.height,
      .pixelFormat = pixelFormat,
      .dataType = frameBuffer.dataType,
      .buffer = _customFormatBuffer,
  };

  int error = 0;
  switch (pixelFormat) {
    case PixelFormat::ARGB:
      // do nothing, we're already in ARGB
      return frameBuffer;
    case RGB:
      error = libyuv::ARGBToRGB24(frameBuffer.data(), frameBuffer.getPixelStride(),
                                  destination.data(), destination.getPixelStride(),
                                  destination.width, destination.height);
      break;
    case BGR:
      throw std::runtime_error("BGR is not supported on Android!");
    case RGBA:
      error = libyuv::ARGBToRGBA(frameBuffer.data(), frameBuffer.getPixelStride(),
                                 destination.data(), destination.getPixelStride(),
                                 destination.width, destination.height);
      break;
    case BGRA:
      error = libyuv::ARGBToBGRA(frameBuffer.data(), frameBuffer.getPixelStride(),
                                 destination.data(), destination.getPixelStride(),
                                 destination.width, destination.height);
      break;
    case ABGR:
      error = libyuv::ARGBToABGR(frameBuffer.data(), frameBuffer.getPixelStride(),
                                 destination.data(), destination.getPixelStride(),
                                 destination.width, destination.height);
      break;
  }

  if (error != 0) {
    throw std::runtime_error("Failed to convert ARGB Buffer to target Pixel Format! Error: " + std::to_string(error));
  }

  return destination;
}

jni::alias_ref<jni::JByteBuffer> ResizePlugin::resize(jni::alias_ref<JImage> image,
                                                      int cropX, int cropY,
                                                      int targetWidth, int targetHeight,
                                                      int /* PixelFormat */ pixelFormatOrdinal, int /* DataType */ dataTypeOrdinal) {
  PixelFormat pixelFormat = static_cast<PixelFormat>(pixelFormatOrdinal);
  DataType dataType = static_cast<DataType>(dataTypeOrdinal);

  // 1. Convert from YUV -> ARGB
  FrameBuffer result = imageToFrameBuffer(image);

  // 2. Convert from ARGB -> ????
  result = convertARGBBufferTo(result, pixelFormat);


  return result.buffer;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
