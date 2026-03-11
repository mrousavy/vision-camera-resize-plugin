import { NitroModules } from 'react-native-nitro-modules'
import type { Frame } from 'react-native-vision-camera'

import type {
  DataType,
  ResizeOptions,
  ResizePlugin,
} from './specs/ResizePlugin.nitro'

export type { DataType, PixelFormat, Rect, Size } from './specs/ResizePlugin.nitro'

export type Rotation = '0deg' | '90deg' | '180deg' | '270deg'

export type OutputArray<T extends DataType> = T extends 'uint8'
  ? Uint8Array
  : T extends 'float32'
    ? Float32Array
    : never

export interface Options<T extends DataType>
  extends Omit<ResizeOptions, 'rotationDegrees' | 'dataType'> {
  rotation?: Rotation
  dataType: T
}

const resizePlugin =
  NitroModules.createHybridObject<ResizePlugin>('ResizePlugin')

function getRotationDegrees(rotation: Rotation | undefined): number | undefined {
  switch (rotation) {
    case undefined:
      return undefined
    case '0deg':
      return 0
    case '90deg':
      return 90
    case '180deg':
      return 180
    case '270deg':
      return 270
  }
}

function resize<T extends DataType>(
  frame: Frame,
  options: Options<T>,
): OutputArray<T> {
  'worklet'
  const nativeOptions: ResizeOptions = {
    ...options,
    rotationDegrees: getRotationDegrees(options.rotation),
  }
  const arrayBuffer = resizePlugin.resize(frame, nativeOptions)

  switch (options.dataType) {
    case 'uint8':
      return new Uint8Array(arrayBuffer) as OutputArray<T>
    case 'float32':
      return new Float32Array(arrayBuffer) as OutputArray<T>
    default:
      throw new Error(`Invalid data type (${options.dataType})!`)
  }
}

export const VisionCameraResizePlugin = {
  resize,
}
