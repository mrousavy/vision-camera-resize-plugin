package com.visioncameraresizeplugin

import android.graphics.Bitmap
import android.graphics.ImageFormat
import android.util.Log
import androidx.annotation.Keep
import com.facebook.jni.HybridData
import com.facebook.jni.annotations.DoNotStrip
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.AbgrBuffer
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.BgraBuffer
import io.github.crow_misia.libyuv.FilterMode
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.Plane
import io.github.crow_misia.libyuv.Rgb24Buffer
import io.github.crow_misia.libyuv.RgbaBuffer
import io.github.crow_misia.libyuv.ext.ImageExt.toI420Buffer
import java.nio.ByteBuffer
import java.nio.ByteOrder

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    @DoNotStrip
    @Keep
    private val mHybridData: HybridData

    private var _resizeBuffer: I420Buffer? = null
    private var _destinationArray: SharedArray? = null
    private var _floatDestinationArray: SharedArray? = null

    companion object {
        private const val TAG = "ResizePlugin"

        init {
            System.loadLibrary("VisionCameraResizePlugin")
        }
    }

    private external fun initHybrid(): HybridData

    init {
        mHybridData = initHybrid()
    }

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetX = 0
        var targetY = 0

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
                    throw Error("Cropping is not yet supported on Android!")
                } else {
                    // by default, do a center crop
                    targetX = (frame.width / 2) - (targetWidth / 2)
                    targetY = (frame.height / 2) - (targetHeight / 2)
                }
                Log.i(TAG, "Target size: $targetWidth x $targetHeight")
            }
        }

        return null
    }
}
