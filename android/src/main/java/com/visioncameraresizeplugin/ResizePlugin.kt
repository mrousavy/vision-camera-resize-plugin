package com.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.media.Image
import android.util.Log
import androidx.annotation.Keep
import com.facebook.jni.HybridData
import com.facebook.jni.annotations.DoNotStrip
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import java.nio.ByteBuffer

@Suppress("KotlinJniMissingFunction") // We're using fbjni
class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
  @DoNotStrip
  @Keep
  private val mHybridData: HybridData

  companion object {
    private const val TAG = "ResizePlugin"

    init {
      System.loadLibrary("VisionCameraResizePlugin")
    }
  }

  init {
    mHybridData = initHybrid()
  }

  private external fun initHybrid(): HybridData
  private external fun resize(
    image: Image,
    cropX: Int,
    cropY: Int,
    cropWidth: Int,
    cropHeight: Int,
    scaleWidth: Int,
    scaleHeight: Int,
    pixelFormat: Int,
    dataType: Int
  ): ByteBuffer

  override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any {
    if (params == null) {
      throw Error("Options cannot be null!")
    }

    var cropWidth = frame.width
    var cropHeight = frame.height
    var cropX = 0
    var cropY = 0
    var scaleWidth = frame.width
    var scaleHeight = frame.height
    var targetFormat = PixelFormat.ARGB
    var targetType = DataType.UINT8

    val scale = params["scale"] as? Map<*, *>
    if (scale != null) {
      val scaleWidthDouble = scale["width"] as? Double
      val scaleHeightDouble = scale["height"] as? Double
      if (scaleWidthDouble != null && scaleHeightDouble != null) {
        scaleWidth = scaleWidthDouble.toInt()
        scaleHeight = scaleHeightDouble.toInt()
      } else {
        throw Error("Failed to parse values in scale dictionary!")
      }
      Log.i(TAG, "Target scale: $scaleWidth x $scaleHeight")
    }

    val crop = params["crop"] as? Map<*, *>
    if (crop != null) {
      val cropWidthDouble = crop["width"] as? Double
      val cropHeightDouble = crop["height"] as? Double
      val cropXDouble = crop["x"] as? Double
      val cropYDouble = crop["y"] as? Double
      if (cropWidthDouble != null && cropHeightDouble != null && cropXDouble != null && cropYDouble != null) {
        cropWidth = cropWidthDouble.toInt()
        cropHeight = cropHeightDouble.toInt()
        cropX = cropXDouble.toInt()
        cropY = cropYDouble.toInt()
        Log.i(TAG, "Target size: $cropWidth x $cropHeight")
      } else {
        throw Error("Failed to parse values in crop dictionary!")
      }
    } else {
      if (scale != null) {
        val aspectRatio = frame.width.toDouble() / frame.height.toDouble()
        val targetAspectRatio = scaleWidth.toDouble() / scaleHeight.toDouble()

        if (aspectRatio > targetAspectRatio) {
          cropWidth = (frame.height * targetAspectRatio).toInt()
          cropHeight = frame.height
        } else {
          cropWidth = frame.width
          cropHeight = (frame.width / targetAspectRatio).toInt()
        }
        cropX = (frame.width / 2) - (cropWidth / 2)
        cropY = (frame.height / 2) - (cropHeight / 2)
        Log.i(TAG, "Cropping to $cropWidth x $cropHeight at ($cropX, $cropY)")
      } else {
        Log.i(TAG, "Both scale and crop are null, using Frame's original dimensions.")
      }
    }

    val formatString = params["pixelFormat"] as? String
    if (formatString != null) {
      targetFormat = PixelFormat.fromString(formatString)
      Log.i(TAG, "Target Format: $targetFormat")
    }

    val dataTypeString = params["dataType"] as? String
    if (dataTypeString != null) {
      targetType = DataType.fromString(dataTypeString)
      Log.i(TAG, "Target DataType: $targetType")
    }

    val image = frame.image

    if (image.format != ImageFormat.YUV_420_888) {
      throw Error("Frame has invalid PixelFormat! Only YUV_420_888 is supported. Did you set pixelFormat=\"yuv\"?")
    }

    val resized = resize(
      image,
      cropX, cropY,
      cropWidth, cropHeight,
      scaleWidth, scaleHeight,
      targetFormat.ordinal, targetType.ordinal
    )
    return SharedArray(proxy, resized)
  }

  private enum class PixelFormat {
    // Integer-Values (ordinals) to be in sync with ResizePlugin.h
    RGB,
    BGR,
    ARGB,
    RGBA,
    BGRA,
    ABGR;

    companion object {
      fun fromString(string: String): PixelFormat =
        when (string) {
          "rgb" -> RGB
          "rgba" -> RGBA
          "argb" -> ARGB
          "bgra" -> BGRA
          "bgr" -> BGR
          "abgr" -> ABGR
          else -> throw Error("Invalid PixelFormat! ($string)")
        }
    }
  }

  private enum class DataType {
    // Integer-Values (ordinals) to be in sync with ResizePlugin.h
    UINT8,
    FLOAT32;

    companion object {
      fun fromString(string: String): DataType =
        when (string) {
          "uint8" -> UINT8
          "float32" -> FLOAT32
          else -> throw Error("Invalid DataType! ($string)")
        }
    }
  }
}
