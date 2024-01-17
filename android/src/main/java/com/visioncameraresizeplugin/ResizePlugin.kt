package com.visioncameraresizeplugin

import android.util.Log
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.asPlane

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    private var _argbBuffer: SharedArray? = null
    companion object {
        private const val TAG = "ResizePlugin"
    }

    enum class RGBFormat {
        RGB_8,
        ARGB_8;

        companion object {
            fun fromString(string: String): RGBFormat {
                return when (string) {
                    "rgb-uint8" -> RGB_8
                    "argb-uint8" -> ARGB_8
                    else -> throw Error("Invalid PixelFormat! ($string)")
                }
            }
        }
    }

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetFormat = RGBFormat.ARGB_8

        val targetSize = params["size"] as? Map<*, *>
        if (targetSize != null) {
            targetWidth = targetSize["width"] as Int
            targetHeight = targetSize["height"] as Int
            Log.i(TAG, "Target size: $targetWidth x $targetHeight")
        }

        val formatString = params["pixelFormat"] as? String
        if (formatString != null) {
            targetFormat = RGBFormat.fromString(formatString)
            Log.i(TAG, "Target Format: $targetFormat")
        }

        val image = frame.image
        val y = image.planes[0].asPlane()
        val u = image.planes[1].asPlane()
        val v = image.planes[2].asPlane()
        val buffer = I420Buffer.wrap(y, u, v, image.width, image.height)

        val argbSize = image.width * image.height * 4
        if (_argbBuffer == null || _argbBuffer!!.byteBuffer.remaining() != argbSize) {
            Log.i(TAG, "Allocating _argbBuffer... (size: $argbSize)")
            _argbBuffer = SharedArray(proxy, SharedArray.Type.Uint8Array, argbSize)
        }
        val argbBuffer = ArgbBuffer.wrap(_argbBuffer!!.byteBuffer, image.width, image.height)
        buffer.convertTo(argbBuffer)

        return _argbBuffer
    }

}