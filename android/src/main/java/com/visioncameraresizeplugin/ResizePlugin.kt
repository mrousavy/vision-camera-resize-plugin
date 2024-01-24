package com.visioncameraresizeplugin

import android.graphics.ImageFormat
import android.util.Log
import com.mrousavy.camera.frameprocessor.Frame
import com.mrousavy.camera.frameprocessor.FrameProcessorPlugin
import com.mrousavy.camera.frameprocessor.SharedArray
import com.mrousavy.camera.frameprocessor.VisionCameraProxy
import io.github.crow_misia.libyuv.AbgrBuffer
import io.github.crow_misia.libyuv.AbstractBuffer
import io.github.crow_misia.libyuv.ArgbBuffer
import io.github.crow_misia.libyuv.BgraBuffer
import io.github.crow_misia.libyuv.FilterMode
import io.github.crow_misia.libyuv.I420Buffer
import io.github.crow_misia.libyuv.Plane
import io.github.crow_misia.libyuv.Rgb24Buffer
import io.github.crow_misia.libyuv.RgbaBuffer
import io.github.crow_misia.libyuv.ext.ImageExt.toI420Buffer
import java.nio.ByteBuffer
import kotlin.math.roundToInt

class ResizePlugin(private val proxy: VisionCameraProxy) : FrameProcessorPlugin() {
    private var _resizeBuffer: I420Buffer? = null
    private var _destinationArray: SharedArray? = null
    companion object {
        private const val TAG = "ResizePlugin"
    }

    private fun wrapArrayInPlane(array: SharedArray, rowStride: Int): Plane {
        return object: Plane {
            override val buffer: ByteBuffer
                get() = array.byteBuffer
            override val rowStride: Int
                get() = rowStride
        }
    }

    private fun getCachedResizeBuffer(width: Int, height: Int): I420Buffer {
        if (_resizeBuffer == null || _resizeBuffer!!.width != width || _resizeBuffer!!.height != height) {
            Log.i(TAG, "Allocating _resizeBuffer... (size: ${width}x${height})")
            _resizeBuffer = I420Buffer.allocate(width, height)
        }
        return _resizeBuffer!!
    }

    override fun callback(frame: Frame, params: MutableMap<String, Any>?): Any? {
        if (params == null) {
            throw Error("Options cannot be null!")
        }

        var targetWidth = frame.width
        var targetHeight = frame.height
        var targetFormat = RGBFormat.ARGB
        var targetType = DataType.UINT8

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

        val dataTypeString = params["dataType"] as? String
        if (dataTypeString != null) {
            targetType = DataType.fromString(dataTypeString)
            Log.i(TAG, "Target DataType: $targetType")
        }

        val image = frame.image
        Log.i(TAG, "Frame Format: ${frame.pixelFormat} (${image.format})")
        if (image.format != ImageFormat.YUV_420_888) {
            throw Error("Frame is not in yuv format! Set pixelFormat=\"yuv\" on the <Camera>. (Expected: YUV_420_888, Received: ${image.format})")
        }

        val buffer = image.toI420Buffer()

        val resizeBuffer = getCachedResizeBuffer(targetWidth, targetHeight)

        Log.i(TAG, "Resizing ${frame.width}x${frame.height} Frame to ${targetWidth}x${targetHeight}...")
        buffer.scale(resizeBuffer, FilterMode.BILINEAR)

        val argbSize = targetWidth * targetHeight * targetFormat.channelsPerPixel
        if (_destinationArray == null || _destinationArray!!.byteBuffer.remaining() != argbSize) {
            Log.i(TAG, "Allocating _argbArray... (size: $argbSize)")
            _destinationArray = SharedArray(proxy, argbSize)
        }
        _destinationArray!!.byteBuffer.rewind()

        val plane = wrapArrayInPlane(_destinationArray!!, targetWidth * targetFormat.channelsPerPixel)

        Log.i(TAG, "Converting to $targetFormat...")
        when (targetFormat) {
            RGBFormat.RGB -> {
                val rgbBuffer = Rgb24Buffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(rgbBuffer)
            }
            RGBFormat.BGR -> {
                throw Error("bgr is not yet implemented!")
            }
            RGBFormat.ARGB -> {
                val rgbBuffer = ArgbBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(rgbBuffer)
            }
            RGBFormat.RGBA -> {
                val rgbBuffer = RgbaBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(rgbBuffer)
            }
            RGBFormat.BGRA -> {
                val rgbBuffer = BgraBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(rgbBuffer)
            }
            RGBFormat.ABGR -> {
                val rgbBuffer = AbgrBuffer.wrap(plane, targetWidth, targetHeight)
                resizeBuffer.convertTo(rgbBuffer)
            }
        }
        Log.i(TAG, "Resized & Converted!")

        return _destinationArray
    }


    enum class RGBFormat {
        RGB,
        BGR,
        ARGB,
        RGBA,
        BGRA,
        ABGR;

        val channelsPerPixel: Int
            get() {
                return when (this) {
                    RGB, BGR -> 3
                    ARGB, RGBA, BGRA, ABGR -> 4
                }
            }

        companion object {
            fun fromString(string: String): RGBFormat {
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

    enum class DataType {
        UINT8,
        FLOAT32;

        val bytesPerValue: Int
            get() {
                return when (this) {
                    UINT8 -> 1
                    FLOAT32 -> 4
                }
            }

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
