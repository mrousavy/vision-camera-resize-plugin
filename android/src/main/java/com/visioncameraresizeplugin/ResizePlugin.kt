package com.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.util.Log
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.FilterMode
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.Plane
import io.github.crow_misia.libyuv.asPlane
import io.github.crow_misia.libyuv.ext.ImageExt.toH420Buffer
import io.github.crow_misia.libyuv.ext.ImageExt.toI420Buffer
import io.github.crow_misia.libyuv.ext.ImageExt.toJ420Buffer
import io.github.crow_misia.libyuv.ext.ImageExt.toNv21Buffer
import io.github.crow_misia.libyuv.ext.ImageExt.toU420Buffer
import java.nio.ByteBuffer

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    private var _resizeArray: SharedArray? = null
    private var _argbArray: SharedArray? = null
    companion object {
        private const val TAG = "ResizePlugin"
    }

    enum class RGBFormat {
        RGB_8,
        BGR_8,
        ARGB_8,
        RGBA_8,
        BGRA_8,
        ABGR_8;

        val bytesPerPixel: Int
            get() {
                return when (this) {
                    RGB_8, BGR_8 -> 3
                    ARGB_8, RGBA_8, BGRA_8, ABGR_8 -> 4
                }
            }

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

    private fun wrapArrayInPlane(array: SharedArray, rowStride: Int): Plane {
        return object: Plane {
            override val buffer: ByteBuffer
                get() = array.byteBuffer
            override val rowStride: Int
                get() = rowStride
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
            val targetWidthDouble = targetSize["width"] as? Double
            val targetHeightDouble = targetSize["height"] as? Double
            if (targetWidthDouble != null && targetHeightDouble != null) {
                targetWidth = targetWidthDouble.toInt()
                targetHeight = targetHeightDouble.toInt()
                Log.i(TAG, "Target size: $targetWidth x $targetHeight")
            }
        }

        val formatString = params["pixelFormat"] as? String
        if (formatString != null) {
            targetFormat = RGBFormat.fromString(formatString)
            Log.i(TAG, "Target Format: $targetFormat")
        }

        val image = frame.image
        Log.i(TAG, "Frame Format: ${frame.pixelFormat} (${image.format})")
        if (image.format != ImageFormat.YUV_420_888) {
            throw Error("Frame is not in yuv format! Set pixelFormat=\"yuv\" on the <Camera>. (Expected: YUV_420_888, Received: ${image.format})")
        }

        Log.i(TAG, "Converting Frame to I420Buffer...")
        val buffer = image.toI420Buffer()

        val totalBufferSize = buffer.planes.sumOf { it.buffer.remaining() }
        val yuvBytesPerPixel = totalBufferSize.toDouble() / image.width / image.height
        Log.i(TAG, "Created I420Buffer (size: $totalBufferSize at $yuvBytesPerPixel bytes per pixel)")
        val resizeSize = (targetWidth * targetHeight * yuvBytesPerPixel).toInt()
        if (_resizeArray == null || _resizeArray!!.byteBuffer.remaining() != resizeSize) {
            Log.i(TAG, "Allocating _resizeArray... (size: $resizeSize)")
            _resizeArray = SharedArray(proxy, SharedArray.Type.Uint8Array, resizeSize)
        }
        val resizeBuffer = I420Buffer.wrap(_resizeArray!!.byteBuffer, targetWidth, targetHeight)

        Log.i(TAG, "Resizing ${frame.width}x${frame.height} Frame to ${targetWidth}x${targetHeight}...")
        buffer.scale(resizeBuffer, FilterMode.BILINEAR)

        val argbSize = targetWidth * targetHeight * targetFormat.bytesPerPixel
        if (_argbArray == null || _argbArray!!.byteBuffer.remaining() != argbSize) {
            Log.i(TAG, "Allocating _argbArray... (size: $argbSize)")
            _argbArray = SharedArray(proxy, SharedArray.Type.Uint8Array, argbSize)
        }
        _argbArray!!.byteBuffer.rewind()
        Log.i(TAG, "Wrapping in ARGB")

        val plane = wrapArrayInPlane(_argbArray!!, targetWidth * targetFormat.bytesPerPixel)
        val argbBuffer = ArgbBuffer.wrap(plane, targetWidth, targetHeight)

        Log.i(TAG, "Converting to ARGB")
        resizeBuffer.convertTo(argbBuffer)
        Log.i(TAG, "Sending back to JS")

        return _argbArray
    }

}