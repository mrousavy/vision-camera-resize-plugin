import type { HybridObject } from 'react-native-nitro-modules'
import type { Frame } from 'react-native-vision-camera'

export type DataType = 'uint8' | 'float32'
export type PixelFormat = 'rgb' | 'rgba' | 'argb' | 'bgra' | 'bgr' | 'abgr'

export interface Size {
  width: number
  height: number
}

export interface Rect extends Size {
  x: number
  y: number
}

export interface ResizeOptions {
  mirror?: boolean
  crop?: Rect
  scale?: Size
  rotationDegrees?: number
  pixelFormat: PixelFormat
  dataType: DataType
}

export interface ResizePlugin
  extends HybridObject<{ ios: 'swift'; android: 'kotlin' }> {
  resize(frame: Frame, options: ResizeOptions): ArrayBuffer
}
