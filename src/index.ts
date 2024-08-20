import { useMemo } from 'react';
import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

export type DataType = 'uint8' | 'float32';
export type OutputArray<T extends DataType> = T extends 'uint8'
  ? Uint8Array
  : T extends 'float32'
    ? Float32Array
    : never;

interface Size {
  width: number;
  height: number;
}

interface Rect extends Size {
  x: number;
  y: number;
}

// /**
//    * If set to `true`, the image will be mirrored horizontally.
//    */
// mirror?: boolean;
// /**
//  * Crops the image to the given target rect. This is applied first before scaling.
//  *
//  * If this is not set, a center-crop to the given target aspect ratio is automatically calculated.
//  */
// crop?: Rect;
// /**
//  * Scale the image to the given target size. This is applied after cropping.
//  */
// scale?: Size;
// /**
//  * Rotate the image by a given amount of degrees, clockwise.
//  * @default '0deg'
//  */
// rotation?: '0deg' | '90deg' | '180deg' | '270deg';

export type ResizeTransform = {
  /**
   * A transform that changes the dimensions of the Frame Buffer
   */
  type: 'resize';
  /**
   * The size the image will be resized to
   */
  targetSize: Size;
};
export type MirrorTransform = {
  /**
   * A transform that mirrors the Frame Buffer horizontally
   */
  type: 'mirror';
};
export type CropTransform = {
  /**
   * A transform that crops out a subsection of the Frame Buffer
   */
  type: 'crop';
  /**
   * The rectangular subsection of the image to be cropped
   */
  rect: Rect;
};
export type RotationTransform = {
  /**
   * A transform that rotates the Frame Buffer about its center
   */
  type: 'crop';
  /**
   * The degrees the image should be rotated by clockwise
   */
  rotation: '0deg' | '90deg' | '180deg' | '270deg';
};
export type Transform =
  | ResizeTransform
  | MirrorTransform
  | CropTransform
  | RotationTransform;

export interface Options<T extends DataType> {
  /**
   * The set of transform operations the Frame should be passed through to produce
   * the final transformed Frame Buffer.
   *
   * These are applied sequentially with the result of the last operation being
   * passed as the input for the next, allowing for a composable set of transforms
   * to be applied.
   */
  transforms: Transform[];
  /**
   * Convert the Frame to the given target pixel format.
   *
   * - `'rgb'`: [R, G, B] layout
   * - `'rgba'`: [R, G, B, A]
   * - `'argb'`: [A, R, G, B]
   * - `'bgra'`: [B, G, R, A]
   * - `'bgr'`: [B, G, R]
   * - `'abgr'`: [A, B, G, R]
   */
  pixelFormat: 'rgb' | 'rgba' | 'argb' | 'bgra' | 'bgr' | 'abgr';
  /**
   * The given type to use for the resulting buffer.
   * Each color channel uses this type for representing pixels.
   *
   * - `'uint8'`: Resulting buffer is a `Uint8Array`, values range from 0 to 255
   * - `'float32'`: Resulting buffer is a `Float32Array`, values range from 0.0 to 1.0
   */
  dataType: T;
}

/**
 * An instance of the transform plugin.
 *
 * All temporary memory buffers allocated by the transform plugin
 * will be deleted once this value goes out of scope.
 */
export interface TransformPlugin {
  /**
   * Transforms the given Frame sequentially through the transformation operations
   * and converts the result to the given pixel format and data type
   */
  transform<T extends DataType>(
    frame: Frame,
    options: Options<T>
  ): OutputArray<T>;
}

/**
 * Get a new instance of the transform plugin.
 *
 * All temporary memory buffers allocated by the transform plugin
 * will be deleted once the returned value goes out of scope.
 */
export function createTransformPlugin(): TransformPlugin {
  const transformPlugin =
    VisionCameraProxy.initFrameProcessorPlugin('transform');

  if (transformPlugin == null) {
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );
  }

  return {
    transform: <T extends DataType>(
      frame: Frame,
      options: Options<T>
    ): OutputArray<T> => {
      'worklet';
      // @ts-expect-error
      const arrayBuffer = transformPlugin.call(frame, options) as ArrayBuffer;

      switch (options.dataType) {
        case 'uint8':
          // @ts-expect-error
          return new Uint8Array(arrayBuffer);
        case 'float32':
          // @ts-expect-error
          return new Float32Array(arrayBuffer);
        default:
          throw new Error(`Invalid data type (${options.dataType})!`);
      }
    },
  };
}

/**
 * Use an instance of the transform plugin.
 *
 * All temporary memory buffers allocated by the transform plugin
 * will be deleted once the component that uses `useTransformPlugin()` unmounts.
 */
export function useTransformPlugin(): TransformPlugin {
  return useMemo(() => createTransformPlugin(), []);
}
