package com.visioncameraresizeplugin

import android.media.Image
import android.graphics.ImageFormat
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
    private external fun resize(image: Image,
                                cropX: Int, cropY: Int,
                                targetWidth: Int, targetHeight: Int,
                                pixelFormat: Int, dataType: Int): ByteBuffer

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetX = 0
        var targetY = 0
        var targetFormat = PixelFormat.ARGB
        var targetType = DataType.UINT8

        val targetSize = params["size"] as? Map<*, *>
        if (targetSize != null) {
            val targetWidthDouble = targetSize["width"] as? Double
            val targetHeightDouble = targetSize["height"] as? Double
            val targetXDouble = targetSize["x"] as? Double
            val targetYDouble = targetSize["y"] as? Double
            if (targetWidthDouble != null && targetHeightDouble != null) {
                targetWidth = targetWidthDouble.toInt()
                targetHeight = targetHeightDouble.toInt()
                if (targetXDouble != null && targetYDouble != null) {
                    targetX = targetXDouble.toInt()
                    targetY = targetYDouble.toInt()
                } else {
                    // by default, do a center crop
                    targetX = (frame.width / 2) - (targetWidth / 2)
                    targetY = (frame.height / 2) - (targetHeight / 2)
                }
                Log.i(TAG, "Target size: $targetWidth x $targetHeight")
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

        val resized = resize(image,
                targetX, targetY,
                targetWidth, targetHeight,
                targetFormat.ordinal, targetType.ordinal)
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
            fun fromString(string: String): PixelFormat {
                return when (string) {
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
    }

    private enum class DataType {
        // Integer-Values (ordinals) to be in sync with ResizePlugin.h
        UINT8,
        FLOAT32;

        companion object {
            fun fromString(string: String): DataType {
                return when (string) {
                    "uint8" -> UINT8
                    "float32" -> FLOAT32
                    else -> throw Error("Invalid DataType! ($string)")
                }
            }
        }
    }
}
