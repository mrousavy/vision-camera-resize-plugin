//
// Created by Marc Rousavy on 25.01.24
//

#include "ResizePlugin.h"
#include "libyuv.h"
#include <android/log.h>
#include <fbjni/fbjni.h>
#include <jni.h>
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

int FrameBuffer::bytesPerRow() {
  size_t bytesPerPixel = getBytesPerPixel(pixelFormat, dataType);
  return width * bytesPerPixel;
}

uint8_t* FrameBuffer::data() {
  return buffer->getDirectBytes();
}

global_ref<JByteBuffer> ResizePlugin::allocateBuffer(size_t size, std::string debugName) {
  __android_log_print(ANDROID_LOG_INFO, TAG, "Allocating %s Buffer with size %zu...", debugName.c_str(), size);
  local_ref<JByteBuffer> buffer = JByteBuffer::allocateDirect(size);
  buffer->order(JByteOrder::nativeOrder());
  return make_global(buffer);
}

FrameBuffer ResizePlugin::imageToFrameBuffer(alias_ref<vision::JImage> image) {
  __android_log_write(ANDROID_LOG_INFO, TAG, "Converting YUV 4:2:0 -> ARGB 8888...");

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
    _argbBuffer = allocateBuffer(argbSize, "_argbBuffer");
  }
  FrameBuffer destination = {
      .width = width,
      .height = height,
      .pixelFormat = PixelFormat::ARGB,
      .dataType = DataType::UINT8,
      .buffer = _argbBuffer,
  };

  // 1. Convert from YUV -> ARGB
  int status = libyuv::Android420ToARGB(yBuffer->getDirectBytes(), yPlane->getRowStride(), uBuffer->getDirectBytes(),
                                        uPlane->getRowStride(), vBuffer->getDirectBytes(), vPlane->getRowStride(), uvPixelStride,
                                        destination.data(), width * channels * channelSize, width, height);

  if (status != 0) {
    throw std::runtime_error("Failed to convert YUV 4:2:0 to ARGB! Error: " + std::to_string(status));
  }

  return destination;
}

std::string rectToString(int x, int y, int width, int height) {
  return std::to_string(x) + ", " + std::to_string(y) + " @ " + std::to_string(width) + "x" + std::to_string(height);
}

FrameBuffer ResizePlugin::cropARGBBuffer(vision::FrameBuffer frameBuffer, int x, int y, int width, int height) {
  if (width == frameBuffer.width && height == frameBuffer.height && x == 0 && y == 0) {
    // already in correct size.
    return frameBuffer;
  }

  auto rectString = rectToString(0, 0, frameBuffer.width, frameBuffer.height);
  auto targetString = rectToString(x, y, width, height);
  __android_log_print(ANDROID_LOG_INFO, TAG, "Cropping [%s] ARGB buffer to [%s]...", rectString.c_str(), targetString.c_str());

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t argbSize = width * height * channels * channelSize;
  if (_cropBuffer == nullptr || _cropBuffer->getDirectSize() != argbSize) {
    _cropBuffer = allocateBuffer(argbSize, "_cropBuffer");
  }
  FrameBuffer destination = {
      .width = width,
      .height = height,
      .pixelFormat = PixelFormat::ARGB,
      .dataType = DataType::UINT8,
      .buffer = _cropBuffer,
  };

  int status = libyuv::ConvertToARGB(frameBuffer.data(), frameBuffer.height * frameBuffer.bytesPerRow(), destination.data(),
                                     destination.bytesPerRow(), x, y, frameBuffer.width, frameBuffer.height, width, height,
                                     libyuv::kRotate0, libyuv::FOURCC_ARGB);
  if (status != 0) {
    throw std::runtime_error("Failed to crop ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::flipARGBBuffer(FrameBuffer frameBuffer, bool flip) {
  if (!flip) {
    return frameBuffer;
  }

  __android_log_print(ANDROID_LOG_INFO, TAG, "Flipping ARGB buffer...");

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t argbSize = frameBuffer.width * frameBuffer.height * channels * channelSize;
  if (_flipBuffer == nullptr || _flipBuffer->getDirectSize() != argbSize) {
    _flipBuffer = allocateBuffer(argbSize, "_flipBuffer");
  }
  FrameBuffer destination = {
          .width = frameBuffer.width,
          .height = frameBuffer.height,
          .pixelFormat = PixelFormat::ARGB,
          .dataType = DataType::UINT8,
          .buffer = _flipBuffer,
  };

  int status = libyuv::ARGBMirror(frameBuffer.data(), frameBuffer.bytesPerRow(),
                                  destination.data(), destination.bytesPerRow(),
                                  frameBuffer.width, frameBuffer.height);
  if (status != 0) {
    throw std::runtime_error("Failed to flip ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::rotateARGBBuffer(FrameBuffer frameBuffer, int rotation) {
  if (rotation == 0) {
    return frameBuffer;
  }

  int rotatedWidth = frameBuffer.width;
  int rotatedHeight = frameBuffer.height;
  if (rotation == 90 || rotation == 270) {
    std::swap(rotatedWidth, rotatedHeight);
  }

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t destinationStride =
          rotation == 90 || rotation == 270 ? rotatedWidth * channels * channelSize
                                            : frameBuffer.bytesPerRow();
  size_t argbSize = rotatedWidth * rotatedHeight * channels * channelSize;

  if (_rotatedBuffer == nullptr || _rotatedBuffer->getDirectSize() != argbSize) {
    _rotatedBuffer = allocateBuffer(argbSize, "_rotatedBuffer");
  }

  FrameBuffer destination = {
          .width = rotatedWidth,
          .height = rotatedHeight,
          .pixelFormat = PixelFormat::ARGB,
          .dataType = DataType::UINT8,
          .buffer = _rotatedBuffer,
  };

  int status = libyuv::ARGBRotate(frameBuffer.data(), frameBuffer.bytesPerRow(),
                                  destination.data(), destinationStride,
                                  frameBuffer.width, frameBuffer.height,
                                  static_cast<libyuv::RotationMode>(rotation));
  if (status != 0) {
    throw std::runtime_error(
            "Failed to rotate ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::scaleARGBBuffer(vision::FrameBuffer frameBuffer, int width, int height) {
  if (width == frameBuffer.width && height == frameBuffer.height) {
    // already in correct size.
    return frameBuffer;
  }
  auto rectString = rectToString(0, 0, frameBuffer.width, frameBuffer.height);
  auto targetString = rectToString(0, 0, width, height);
  __android_log_print(ANDROID_LOG_INFO, TAG, "Scaling [%s] ARGB buffer to [%s]...", rectString.c_str(), targetString.c_str());


  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t argbSize = width * height * channels * channelSize;
  if (_scaleBuffer == nullptr || _scaleBuffer->getDirectSize() != argbSize) {
    _scaleBuffer = allocateBuffer(argbSize, "_scaleBuffer");
  }
  FrameBuffer destination = {
      .width = width,
      .height = height,
      .pixelFormat = PixelFormat::ARGB,
      .dataType = DataType::UINT8,
      .buffer = _scaleBuffer,
  };

  int status = libyuv::ARGBScale(frameBuffer.data(), frameBuffer.bytesPerRow(), frameBuffer.width, frameBuffer.height, destination.data(),
                                 destination.bytesPerRow(), width, height, libyuv::FilterMode::kFilterBilinear);
  if (status != 0) {
    throw std::runtime_error("Failed to scale ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::convertARGBBufferTo(FrameBuffer frameBuffer, PixelFormat pixelFormat) {
  if (frameBuffer.pixelFormat == pixelFormat) {
    // Already in the correct format.
    return frameBuffer;
  }

  __android_log_print(ANDROID_LOG_INFO, TAG, "Converting ARGB Buffer to Pixel Format %zu...", pixelFormat);

  size_t bytesPerPixel = getBytesPerPixel(pixelFormat, frameBuffer.dataType);
  size_t targetBufferSize = frameBuffer.width * frameBuffer.height * bytesPerPixel;
  if (_customFormatBuffer == nullptr || _customFormatBuffer->getDirectSize() != targetBufferSize) {
    _customFormatBuffer = allocateBuffer(targetBufferSize, "_customFormatBuffer");
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
      error = libyuv::ARGBToRGB24(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                  destination.width, destination.height);
      break;
    case BGR:
      throw std::runtime_error("BGR is not supported on Android!");
    case RGBA:
      error = libyuv::ARGBToRGBA(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                 destination.width, destination.height);
      break;
    case BGRA:
      error = libyuv::ARGBToBGRA(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                 destination.width, destination.height);
      break;
    case ABGR:
      error = libyuv::ARGBToABGR(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                 destination.width, destination.height);
      break;
  }

  if (error != 0) {
    throw std::runtime_error("Failed to convert ARGB Buffer to target Pixel Format! Error: " + std::to_string(error));
  }

  return destination;
}

FrameBuffer ResizePlugin::convertBufferToDataType(FrameBuffer frameBuffer, DataType dataType) {
  if (frameBuffer.dataType == dataType) {
    // Already in correct data-type
    return frameBuffer;
  }

  __android_log_print(ANDROID_LOG_INFO, TAG, "Converting ARGB Buffer to Data Type %zu...", dataType);

  size_t targetSize = frameBuffer.width * frameBuffer.height * getBytesPerPixel(frameBuffer.pixelFormat, dataType);
  if (_customTypeBuffer == nullptr || _customTypeBuffer->getDirectSize() != targetSize) {
    _customTypeBuffer = allocateBuffer(targetSize, "_customTypeBuffer");
  }
  size_t size = frameBuffer.buffer->getDirectSize();
  FrameBuffer destination = {
      .width = frameBuffer.width,
      .height = frameBuffer.height,
      .pixelFormat = frameBuffer.pixelFormat,
      .dataType = dataType,
      .buffer = _customTypeBuffer,
  };

  int status = 0;
  switch (dataType) {
    case UINT8:
      // it's already uint8
      return frameBuffer;
    case FLOAT32: {
      float* floatData = reinterpret_cast<float*>(destination.data());
      status = libyuv::ByteToFloat(frameBuffer.data(), floatData, 1.0f / 255.0f, size);
      break;
    }
  }

  if (status != 0) {
    throw std::runtime_error("Failed to convert Buffer to target Data Type! Error: " + std::to_string(status));
  }

  return destination;
}

jni::global_ref<jni::JByteBuffer> ResizePlugin::resize(jni::alias_ref<JImage> image,
                                                       int cropX, int cropY,
                                                       int cropWidth, int cropHeight,
                                                       int scaleWidth, int scaleHeight,
                                                       int rotation,
                                                       bool flip,
                                                       int /* PixelFormat */ pixelFormatOrdinal,
                                                       int /* DataType */ dataTypeOrdinal)
{
  PixelFormat pixelFormat = static_cast<PixelFormat>(pixelFormatOrdinal);
  DataType dataType = static_cast<DataType>(dataTypeOrdinal);

  // 1. Convert from YUV -> ARGB
  FrameBuffer result = imageToFrameBuffer(image);

  // 2. Crop ARGB
  result = cropARGBBuffer(result, cropX, cropY, cropWidth, cropHeight);

  // 3. Scale ARGB
  result = scaleARGBBuffer(result, scaleWidth, scaleHeight);

  // 4. Rotate ARGB
  result = rotateARGBBuffer(result, rotation);

  // 5 Flip ARGB if needed
  result = flipARGBBuffer(result, flip);

  // 5. Convert from ARGB -> ????
  result = convertARGBBufferTo(result, pixelFormat);

  // 6. Convert from data type to other data type
  result = convertBufferToDataType(result, dataType);

  return result.buffer;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
