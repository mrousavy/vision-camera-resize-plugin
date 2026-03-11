import Foundation
import NitroModules
import VisionCamera

private func getScale(options: ResizeOptions, frame: any HybridFrameSpec) -> Size {
  return options.scale ?? Size(width: frame.width, height: frame.height)
}

private func getCrop(options: ResizeOptions, frame: any HybridFrameSpec, scale: Size) -> Rect {
  if let crop = options.crop {
    return crop
  }

  guard options.scale != nil else {
    return Rect(x: 0, y: 0, width: frame.width, height: frame.height)
  }

  let aspectRatio = frame.width / frame.height
  let targetAspectRatio = scale.width / scale.height

  if aspectRatio > targetAspectRatio {
    let cropWidth = frame.height * targetAspectRatio
    return Rect(x: (frame.width / 2.0) - (cropWidth / 2.0), y: 0, width: cropWidth, height: frame.height)
  } else {
    let cropHeight = frame.width / targetAspectRatio
    return Rect(x: 0, y: (frame.height / 2.0) - (cropHeight / 2.0), width: frame.width, height: cropHeight)
  }
}

private func getPixelFormatValue(_ pixelFormat: PixelFormat) -> Int {
  switch pixelFormat {
    case .rgb:
      return 0
    case .rgba:
      return 1
    case .argb:
      return 2
    case .bgra:
      return 3
    case .bgr:
      return 4
    case .abgr:
      return 5
  }
}

private func getDataTypeValue(_ dataType: DataType) -> Int {
  switch dataType {
    case .uint8:
      return 0
    case .float32:
      return 1
  }
}

class HybridResizePlugin: HybridResizePluginSpec {
  private let processor = ResizeProcessor()

  func resize(frame: any HybridFrameSpec, options: ResizeOptions) throws -> ArrayBuffer {
    guard let nativeFrame = frame as? NativeFrame else {
      throw RuntimeError.error(withMessage: "Expected VisionCamera NativeFrame.")
    }
    guard let sampleBuffer = nativeFrame.sampleBuffer else {
      throw RuntimeError.error(withMessage: "The given Frame has already been disposed.")
    }

    let scale = getScale(options: options, frame: frame)
    let crop = getCrop(options: options, frame: frame, scale: scale)

    let result = try processor.resize(
      sampleBuffer,
      cropX: Int(crop.x),
      cropY: Int(crop.y),
      cropWidth: Int(crop.width),
      cropHeight: Int(crop.height),
      scaleWidth: Int(scale.width),
      scaleHeight: Int(scale.height),
      rotation: Int(options.rotationDegrees ?? 0),
      mirror: options.mirror ?? false,
      pixelFormat: getPixelFormatValue(options.pixelFormat),
      dataType: getDataTypeValue(options.dataType)
    )

    guard let data = result.takeData() else {
      throw RuntimeError.error(withMessage: "VisionCameraResizePlugin failed to transfer frame buffer ownership.")
    }

    return ArrayBuffer.wrap(dataWithoutCopy: data, size: Int(result.size)) {
      free(data)
    }
  }
}
