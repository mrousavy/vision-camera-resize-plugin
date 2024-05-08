//
// Created by Marc Rousavy on 25.01.24
//

#pragma once

#include <fbjni/ByteBuffer.h>
#include <fbjni/fbjni.h>
#include <jni.h>
#include <memory>
#include <string>

#include "JImage.h"

namespace vision {

using namespace facebook;
using namespace jni;

enum PixelFormat { RGB, BGR, ARGB, RGBA, BGRA, ABGR };

enum SourceImageFormat { RGBA_8888 = 1, YUV_420_888 = 35 };

enum DataType { UINT8, FLOAT32 };

enum Rotation { Rotation0 = 0, Rotation90 = 90, Rotation180 = 180, Rotation270 = 270 };

struct FrameBuffer {
  int width;
  int height;
  PixelFormat pixelFormat;
  DataType dataType;
  global_ref<JByteBuffer> buffer;

  uint8_t* data() const;
  int bytesPerRow() const;
};

struct ResizePlugin : public HybridClass<ResizePlugin> {
public:
  static auto constexpr kJavaDescriptor = "Lcom/visioncameraresizeplugin/ResizePlugin;";
  static void registerNatives();

private:
  explicit ResizePlugin(const alias_ref<jhybridobject>& javaThis);

  global_ref<JByteBuffer> resize(alias_ref<JImage> image, int cropX, int cropY, int cropWidth, int cropHeight, int scaleWidth,
                                 int scaleHeight, int /* Rotation */ rotation, bool mirror, int /* PixelFormat */ pixelFormat,
                                 int /* DataType */ dataType, int /* SourceImageFormat */ sourceImageFormat);

  FrameBuffer imageYUVToFrameBuffer(alias_ref<JImage> image);
  FrameBuffer imageRGBAToFrameBuffer(alias_ref<JImage> image);
  FrameBuffer cropARGBBuffer(const FrameBuffer& frameBuffer, int x, int y, int width, int height);
  FrameBuffer scaleARGBBuffer(const FrameBuffer& frameBuffer, int width, int height);
  FrameBuffer convertARGBBufferTo(const FrameBuffer& frameBuffer, PixelFormat toFormat);
  FrameBuffer convertBufferToDataType(const FrameBuffer& frameBuffer, DataType dataType);
  FrameBuffer rotateARGBBuffer(const FrameBuffer& frameBuffer, Rotation rotation);
  FrameBuffer mirrorARGBBuffer(const FrameBuffer& frameBuffer, bool mirror);
  global_ref<JByteBuffer> allocateBuffer(size_t size, std::string debugName);

private:
  static auto constexpr TAG = "ResizePlugin";
  friend HybridBase;
  global_ref<javaobject> _javaThis;
  // YUV (?x?) -> ARGB (?x?)
  global_ref<JByteBuffer> _argbBuffer;
  // ARGB (?x?) -> ARGB (!x!)
  global_ref<JByteBuffer> _cropBuffer;
  global_ref<JByteBuffer> _scaleBuffer;
  global_ref<JByteBuffer> _rotatedBuffer;
  global_ref<JByteBuffer> _mirrorBuffer;
  // ARGB (?x?) -> !!!! (?x?)
  global_ref<JByteBuffer> _customFormatBuffer;
  // Custom Data Type (e.g. float32)
  global_ref<JByteBuffer> _customTypeBuffer;

  static local_ref<jhybriddata> initHybrid(alias_ref<jhybridobject> javaThis);
};

} // namespace vision
