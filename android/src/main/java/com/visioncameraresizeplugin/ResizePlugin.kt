package com.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.graphics.PixelFormat as AndroidPixelFormat
import android.media.Image
import android.util.Log
import androidx.annotation.Keep
import com.facebook.jni.HybridData
import com.facebook.jni.annotations.DoNotStrip
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableArray
import com.mrousavy.camera.frameprocessors.Frame
import com.mrousavy.camera.frameprocessors.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessors.SharedArray
import com.mrousavy.camera.frameprocessors.VisionCameraProxy
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
  private external fun transform(
    image: Image,
    transformOperations: Array<Map<String, Any?>>,
    pixelFormat: Int,
    dataType: Int
  ): ByteBuffer

  override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any {
    if (params == null) {
      throw Error("Options cannot be null!")
    }

    val image = frame.image

    if (image.format != ImageFormat.YUV_420_888 && image.format != AndroidPixelFormat.RGBA_8888) {
      throw Error(
        """
          |Frame has invalid PixelFormat! Only YUV_420_888 and  RGBA_8888 are supported. 
          |Did you set pixelFormat=\"yuv\" or \"rgb\"?
        """.trimMargin()
      )
    }

    var targetFormat = PixelFormat.ARGB
    var targetType = DataType.UINT8

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

    val transformOperations = arrayListOf<Map<String, Any?>>()
    val transformsParamArray = params["transforms"] as? List<*>
    if (transformsParamArray != null) {
      for (element in transformsParamArray) {
        val transformOp = element ?: continue
        if (transformOp as? Map<String, *> == null) continue
        transformOperations.add(transformOp)
      }
    }

    val resized = transform(
      image,
      transformOperations.toTypedArray(),
      targetFormat.ordinal,
      targetType.ordinal
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
