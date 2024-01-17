import { useRef } from 'react';
import { Frame, VisionCameraProxy } from 'react-native-vision-camera';

interface Options {
  /**
   * Scale the image to the given target size.
   */
  size?: {
    width: number;
    height: number;
  };
  /**
   * Convert the Frame to the given target pixel format.
   *
   * - `rgb-uint8`: [R, G, B] layout in a Uint8Array (values range from 0...255)
   * - `'rgba-uint8'`: [R, G, B, A] layout in a Uint8Array (values range from 0...255)
   * - `'argb-uint8'`: [A, R, G, B] layout in a Uint8Array (values range from 0...255)
   * - `'bgra-uint8'`: [B, G, R, A] layout in a Uint8Array (values range from 0...255)
   * - `'bgr-uint8'`: [B, G, R] layout in a Uint8Array (values range from 0...255)
   * - `'abgr-uint8'`: [A, B, G, R] layout in a Uint8Array (values range from 0...255)
   */
  pixelFormat:
    | 'rgb-uint8'
    | 'rgba-uint8'
    | 'argb-uint8'
    | 'bgra-uint8'
    | 'bgr-uint8'
    | 'abgr-uint8';
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
  resize(frame: Frame, options: Options): ArrayBuffer;
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
    resize: (frame, options): ArrayBuffer => {
      'worklet';
      // @ts-expect-error
      return resizePlugin.call(frame, options);
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
  const plugin = useRef<ResizePlugin>();
  if (plugin.current == null) plugin.current = createResizePlugin();
  return plugin.current;
}
