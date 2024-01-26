//
// Created by Marc Rousavy on 25.01.24
//

#pragma once

#include <fbjni/fbjni.h>
#include <fbjni/ByteBuffer.h>
#include <jni.h>
#include <memory>
#include <string>

#include "JImage.h"

namespace vision {

using namespace facebook;
using namespace jni;

enum PixelFormat {
  RGB,
  BGR,
  ARGB,
  RGBA,
  BGRA,
  ABGR
};

enum DataType {
  UINT8,
  FLOAT32
};

struct FrameBuffer {
  int width;
  int height;
  PixelFormat pixelFormat;
  DataType dataType;
  global_ref<JByteBuffer> buffer;

  uint8_t* data();
  int bytesPerRow();
};

struct ResizePlugin : public HybridClass<ResizePlugin> {
public:
  static auto constexpr kJavaDescriptor = "Lcom/visioncameraresizeplugin/ResizePlugin;";
  static void registerNatives();

private:
  explicit ResizePlugin(const alias_ref<jhybridobject>& javaThis);

  global_ref<JByteBuffer> resize(alias_ref<JImage> image,
                                 int cropX, int cropY,
                                 int cropWidth, int cropHeight,
                                 int scaleWidth, int scaleHeight,
                                 int /* PixelFormat */ pixelFormat, int /* DataType */ dataType);

  FrameBuffer imageToFrameBuffer(alias_ref<JImage> image);
  FrameBuffer cropARGBBuffer(FrameBuffer frameBuffer, int x, int y, int width, int height);
  FrameBuffer scaleARGBBuffer(FrameBuffer frameBuffer, int width, int height);
  FrameBuffer convertARGBBufferTo(FrameBuffer frameBuffer, PixelFormat toFormat);
  FrameBuffer convertBufferToDataType(FrameBuffer frameBuffer, DataType dataType);

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
  // ARGB (?x?) -> !!!! (?x?)
  global_ref<JByteBuffer> _customFormatBuffer;
  // Custom Data Type (e.g. float32)
  global_ref<JByteBuffer> _customTypeBuffer;

  static local_ref<jhybriddata> initHybrid(alias_ref<jhybridobject> javaThis);
};

} // namespace vision
