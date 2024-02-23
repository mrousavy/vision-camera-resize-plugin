import { useMemo } from 'react';
import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

type DataType = 'uint8' | 'float32';
type OutputArray<T extends DataType> = T extends 'uint8'
  ? Uint8Array
  : T extends 'float32'
  ? Float32Array
  : never;

interface Size {
  /**
   * The width to resize the Frame to.
   */
  width: number;
  /**
   * The height to resize the Frame to.
   */
  height: number;
}

interface Rect extends Size {
  /**
   * The origin X of the Frame used for cropping. If not set, a center-crop will be performed.
   */
  x: number;
  /**
   * The origin Y of the Frame used for cropping. If not set, a center-crop will be performed.
   */
  y: number;
}

interface Options<T extends DataType> {
  /**
   * Crops the image to the given target rect. This is applied first before scaling.
   *
   * If this is not set, a center-crop to the given target aspect ratio is automatically calculated.
   */
  crop?: Rect;
  /**
   * Scale the image to the given target size. This is applied after cropping.
   */
  scale?: Size;
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
 * An instance of the resize plugin.
 *
 * All temporary memory buffers allocated by the resize plugin
 * will be deleted once this value goes out of scope.
 */
interface ResizePlugin {
  /**
   * Resizes the given Frame to the target width/height and
   * convert it to the given pixel format.
   */
  resize<T extends DataType>(frame: Frame, options: Options<T>): OutputArray<T>;
}

/**
 * Get a new instance of the resize plugin.
 *
 * All temporary memory buffers allocated by the resize plugin
 * will be deleted once the returned value goes out of scope.
 */
export function createResizePlugin(): ResizePlugin {
  const resizePlugin = VisionCameraProxy.initFrameProcessorPlugin('resize');

  if (resizePlugin == null) {
    throw new Error(
      'Cannot find vision-camera-resize-plugin! Did you install the native dependency properly?'
    );
  }

  return {
    resize: <T extends DataType>(
      frame: Frame,
      options: Options<T>
    ): OutputArray<T> => {
      'worklet';
      // @ts-expect-error
      const arrayBuffer = resizePlugin.call(frame, options) as ArrayBuffer;

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
 * Use an instance of the resize plugin.
 *
 * All temporary memory buffers allocated by the resize plugin
 * will be deleted once the component that uses `useResizePlugin()` unmounts.
 */
export function useResizePlugin(): ResizePlugin {
  return useMemo(() => createResizePlugin(), []);
}
