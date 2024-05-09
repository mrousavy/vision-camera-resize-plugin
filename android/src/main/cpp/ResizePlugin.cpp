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

libyuv::RotationMode getRotationModeForRotation(Rotation rotation) {
  switch (rotation) {
    case Rotation0:
      return libyuv::RotationMode::kRotate0;
    case Rotation90:
      return libyuv::RotationMode::kRotate90;
    case Rotation180:
      return libyuv::RotationMode::kRotate180;
    case Rotation270:
      return libyuv::RotationMode::kRotate270;
  }
}

int FrameBuffer::bytesPerRow() const {
  size_t bytesPerPixel = getBytesPerPixel(pixelFormat, dataType);
  return width * bytesPerPixel;
}

uint8_t* FrameBuffer::data() const {
  return buffer->getDirectBytes();
}

global_ref<JByteBuffer> ResizePlugin::allocateBuffer(size_t size, std::string debugName) {
  __android_log_print(ANDROID_LOG_INFO, TAG, "Allocating %s Buffer with size %zu...", debugName.c_str(), size);
  local_ref<JByteBuffer> buffer = JByteBuffer::allocateDirect(size);
  buffer->order(JByteOrder::nativeOrder());
  return make_global(buffer);
}

FrameBuffer ResizePlugin::imageToFrameBuffer(alias_ref<vision::JImage> image) {
  jni::local_ref<JArrayClass<JImagePlane>> planes = image->getPlanes();

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

  int sourceImageFormat = image->getFormat();
  int status;

  switch (sourceImageFormat) {
    case SourceImageFormat::RGBA_8888: {
      __android_log_write(ANDROID_LOG_INFO, TAG, "Converting RGBA 8888 -> ARGB 8888...");
      jni::local_ref<JImagePlane> rgbaPlane = planes->getElement(0);
      jni::local_ref<JByteBuffer> rgbaBuffer = rgbaPlane->getBuffer();
      // 1. Convert from RGBA -> ARGB
      status = libyuv::RGBAToARGB(rgbaBuffer->getDirectBytes(), rgbaPlane->getRowStride(), destination.data(),
                                  width * channels * channelSize, width, height);

      if (status != 0) {
        [[unlikely]];
        throw std::runtime_error("Failed to convert RGBA 8888 to ARGB! Error: " + std::to_string(status));
      }
      break;
    }
    default: /* SourceImageFormat.YUV_420_888 */
    {
      __android_log_write(ANDROID_LOG_INFO, TAG, "Converting YUV 4:2:0 -> ARGB 8888...");
      jni::local_ref<JImagePlane> yPlane = planes->getElement(0);
      jni::local_ref<JByteBuffer> yBuffer = yPlane->getBuffer();
      jni::local_ref<JImagePlane> uPlane = planes->getElement(1);
      jni::local_ref<JByteBuffer> uBuffer = uPlane->getBuffer();
      jni::local_ref<JImagePlane> vPlane = planes->getElement(2);
      jni::local_ref<JByteBuffer> vBuffer = vPlane->getBuffer();

      size_t uvPixelStride = uPlane->getPixelStride();
      if (uPlane->getPixelStride() != vPlane->getPixelStride()) {
        [[unlikely]];
        throw std::runtime_error("U and V planes do not have the same pixel stride! Are you sure this is a 4:2:0 YUV format?");
      }

      // 1. Convert from YUV -> ARGB
      status = libyuv::Android420ToARGB(yBuffer->getDirectBytes(), yPlane->getRowStride(), uBuffer->getDirectBytes(),
                                        uPlane->getRowStride(), vBuffer->getDirectBytes(), vPlane->getRowStride(), uvPixelStride,
                                        destination.data(), width * channels * channelSize, width, height);

      if (status != 0) {
        [[unlikely]];
        throw std::runtime_error("Failed to convert YUV 4:2:0 to ARGB! Error: " + std::to_string(status));
      }
      break;
    }
  }

  return destination;
}

std::string rectToString(int x, int y, int width, int height) {
  return std::to_string(x) + ", " + std::to_string(y) + " @ " + std::to_string(width) + "x" + std::to_string(height);
}

FrameBuffer ResizePlugin::cropARGBBuffer(const FrameBuffer& frameBuffer, int x, int y, int width, int height) {
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
    [[unlikely]];
    throw std::runtime_error("Failed to crop ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::mirrorARGBBuffer(const FrameBuffer& frameBuffer, bool mirror) {
  if (!mirror) {
    return frameBuffer;
  }

  __android_log_print(ANDROID_LOG_INFO, TAG, "Mirroring ARGB buffer...");

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t argbSize = frameBuffer.width * frameBuffer.height * channels * channelSize;
  if (_mirrorBuffer == nullptr || _mirrorBuffer->getDirectSize() != argbSize) {
    _mirrorBuffer = allocateBuffer(argbSize, "_mirrorBuffer");
  }
  FrameBuffer destination = {
      .width = frameBuffer.width,
      .height = frameBuffer.height,
      .pixelFormat = PixelFormat::ARGB,
      .dataType = DataType::UINT8,
      .buffer = _mirrorBuffer,
  };

  int status = libyuv::ARGBMirror(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                  frameBuffer.width, frameBuffer.height);
  if (status != 0) {
    [[unlikely]];
    throw std::runtime_error("Failed to mirror ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::rotateARGBBuffer(const FrameBuffer& frameBuffer, Rotation rotation) {
  if (rotation == Rotation::Rotation0) {
    return frameBuffer;
  }

  __android_log_print(ANDROID_LOG_INFO, TAG, "Rotating ARGB buffer by %zu degrees...", static_cast<int>(rotation));

  int rotatedWidth, rotatedHeight;
  if (rotation == Rotation90 || rotation == Rotation270) {
    // flipped to the side
    rotatedWidth = frameBuffer.height;
    rotatedHeight = frameBuffer.width;
  } else {
    // still uprighht, maybe upside down.
    rotatedWidth = frameBuffer.width;
    rotatedHeight = frameBuffer.height;
  }

  size_t channels = getChannelCount(PixelFormat::ARGB);
  size_t channelSize = getBytesPerChannel(DataType::UINT8);
  size_t destinationStride = rotatedWidth * channels * channelSize;
  size_t rotateSize = frameBuffer.buffer->getDirectSize();

  if (_rotatedBuffer == nullptr || _rotatedBuffer->getDirectSize() != rotateSize) {
    _rotatedBuffer = allocateBuffer(rotateSize, "_rotatedBuffer");
  }

  FrameBuffer destination = {
      .width = rotatedWidth,
      .height = rotatedHeight,
      .pixelFormat = PixelFormat::ARGB,
      .dataType = DataType::UINT8,
      .buffer = _rotatedBuffer,
  };

  libyuv::RotationMode rotationMode = getRotationModeForRotation(rotation);
  int status = libyuv::ARGBRotate(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destinationStride, frameBuffer.width,
                                  frameBuffer.height, rotationMode);
  if (status != 0) {
    [[unlikely]];
    throw std::runtime_error("Failed to rotate ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::scaleARGBBuffer(const FrameBuffer& frameBuffer, int width, int height) {
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
    [[unlikely]];
    throw std::runtime_error("Failed to scale ARGB Buffer! Status: " + std::to_string(status));
  }

  return destination;
}

FrameBuffer ResizePlugin::convertARGBBufferTo(const FrameBuffer& frameBuffer, PixelFormat pixelFormat) {
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
      // RAW is [R, G, B] in libyuv memory layout
      error = libyuv::ARGBToRAW(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                destination.width, destination.height);
      break;
    case BGR:
      // RGB24 is [B, G, R] in libyuv memory layout
      error = libyuv::ARGBToRGB24(frameBuffer.data(), frameBuffer.bytesPerRow(), destination.data(), destination.bytesPerRow(),
                                  destination.width, destination.height);
      break;
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
    [[unlikely]];
    throw std::runtime_error("Failed to convert ARGB Buffer to target Pixel Format! Error: " + std::to_string(error));
  }

  return destination;
}

FrameBuffer ResizePlugin::convertBufferToDataType(const FrameBuffer& frameBuffer, DataType dataType) {
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
    [[unlikely]];
    throw std::runtime_error("Failed to convert Buffer to target Data Type! Error: " + std::to_string(status));
  }

  return destination;
}

jni::global_ref<jni::JByteBuffer> ResizePlugin::resize(jni::alias_ref<JImage> image, int cropX, int cropY, int cropWidth, int cropHeight,
                                                       int scaleWidth, int scaleHeight, int /* Rotation */ rotationOrdinal, bool mirror,
                                                       int /* PixelFormat */ pixelFormatOrdinal, int /* DataType */ dataTypeOrdinal) {
  PixelFormat pixelFormat = static_cast<PixelFormat>(pixelFormatOrdinal);
  DataType dataType = static_cast<DataType>(dataTypeOrdinal);
  Rotation rotation = static_cast<Rotation>(rotationOrdinal);

  // 1. Convert from YUV/RGBA -> ARGB
  FrameBuffer result = imageToFrameBuffer(image);

  // 2. Crop ARGB
  result = cropARGBBuffer(result, cropX, cropY, cropWidth, cropHeight);

  // 3. Scale ARGB
  result = scaleARGBBuffer(result, scaleWidth, scaleHeight);

  // 4. Rotate ARGB
  result = rotateARGBBuffer(result, rotation);

  // 5 Mirror ARGB if needed
  result = mirrorARGBBuffer(result, mirror);

  // 6. Convert from ARGB -> ????
  result = convertARGBBufferTo(result, pixelFormat);

  // 7. Convert from data type to other data type
  result = convertBufferToDataType(result, dataType);

  return result.buffer;
}

jni::local_ref<ResizePlugin::jhybriddata> ResizePlugin::initHybrid(jni::alias_ref<jhybridobject> javaThis) {
  return makeCxxInstance(javaThis);
}

} // namespace vision
