package com.margelo.nitro.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.graphics.PixelFormat as AndroidPixelFormat
import androidx.annotation.Keep
import androidx.camera.core.ExperimentalGetImage
import com.facebook.proguard.annotations.DoNotStrip
import com.margelo.nitro.camera.HybridFrameSpec
import com.margelo.nitro.camera.public.NativeFrame
import com.margelo.nitro.core.ArrayBuffer

private fun getScale(options: ResizeOptions, frame: HybridFrameSpec): Size {
  return options.scale ?: Size(frame.width, frame.height)
}

private fun getCrop(options: ResizeOptions, frame: HybridFrameSpec, scale: Size): Rect {
  options.crop?.let { return it }

  if (options.scale == null) {
    return Rect(0.0, 0.0, frame.width, frame.height)
  }

  val aspectRatio = frame.width / frame.height
  val targetAspectRatio = scale.width / scale.height

  return if (aspectRatio > targetAspectRatio) {
    val cropWidth = frame.height * targetAspectRatio
    Rect((frame.width / 2.0) - (cropWidth / 2.0), 0.0, cropWidth, frame.height)
  } else {
    val cropHeight = frame.width / targetAspectRatio
    Rect(0.0, (frame.height / 2.0) - (cropHeight / 2.0), frame.width, cropHeight)
  }
}

@DoNotStrip
@Keep
class HybridResizePlugin : HybridResizePluginSpec() {
  private val processor = ResizeProcessor()

  @OptIn(ExperimentalGetImage::class)
  override fun resize(frame: HybridFrameSpec, options: ResizeOptions): ArrayBuffer {
    val nativeFrame = frame as? NativeFrame ?: throw Error("Expected VisionCamera NativeFrame.")
    val imageProxy = nativeFrame.image
    val image = imageProxy.image ?: throw Error("The given Frame has already been disposed.")

    if (image.format != ImageFormat.YUV_420_888 && image.format != AndroidPixelFormat.RGBA_8888) {
      throw Error(
        """
          |Frame has invalid PixelFormat! Only YUV_420_888 and RGBA_8888 are supported.
          |Configure the VisionCamera Frame Output with pixelFormat="yuv" or "rgb".
        """.trimMargin(),
      )
    }

    val scale = getScale(options, frame)
    val crop = getCrop(options, frame, scale)
    val resized = processor.resize(
      image,
      crop.x.toInt(),
      crop.y.toInt(),
      crop.width.toInt(),
      crop.height.toInt(),
      scale.width.toInt(),
      scale.height.toInt(),
      options.rotationDegrees?.toInt() ?: 0,
      options.mirror ?: false,
      options.pixelFormat.value,
      options.dataType.value,
    )
    return ArrayBuffer.wrap(resized)
  }
}
