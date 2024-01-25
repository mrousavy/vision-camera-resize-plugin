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

jni::local_ref<jni::JByteBuffer> ResizePlugin::resize(jni::alias_ref<JImage> image,
                                                      int cropX, int cropY,
                                                      int targetWidth, int targetHeight,
                                                      int /* PixelFormat */ pixelFormatOrdinal, int /* DataType */ dataTypeOrdinal) {
  PixelFormat pixelFormat = static_cast<PixelFormat>(pixelFormatOrdinal);
  DataType dataType = static_cast<DataType>(dataTypeOrdinal);

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

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  jni::local_ref<JByteBuffer> destinationBuffer = JByteBuffer::allocateDirect(targetWidth * targetHeight * channels * channelSize);
  auto destination = destinationBuffer->getDirectBytes();

  int result = libyuv::Android420ToARGB(yBuffer->getDirectBytes(), yPlane->getRowStride(),
                                        uBuffer->getDirectBytes(), uPlane->getRowStride(),
                                        vBuffer->getDirectBytes(), vPlane->getRowStride(),
                                        uvPixelStride,
                                        destination, targetWidth * channels * channelSize,
                                        targetWidth, targetHeight);

  if (result != 0) {
    throw std::runtime_error("Failed to convert YUV 4:2:0 to ARGB! Error: " + std::to_string(result));
  }

  return destinationBuffer;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
