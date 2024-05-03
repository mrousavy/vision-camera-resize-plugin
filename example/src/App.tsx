import * as React from 'react';

import { StyleSheet, View } from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { Options, useResizePlugin } from 'vision-camera-resize-plugin';
import { useSharedValue } from 'react-native-reanimated';
import {
  Skia,
  AlphaType,
  ColorType,
  Image,
  SkData,
  Canvas,
  SkImage,
} from '@shopify/react-native-skia';
import { useRunOnJS } from 'react-native-worklets-core';

const WIDTH = 480;
const HEIGHT = 640;
const TARGET_TYPE = 'uint8' as const;

type PixelFormat = Options<typeof TARGET_TYPE>['pixelFormat'];
const TARGET_FORMAT: PixelFormat = 'rgba';

let lastWarn: PixelFormat | undefined;
lastWarn = undefined;
function warnNotSupported(pixelFormat: PixelFormat) {
  if (lastWarn !== pixelFormat) {
    console.log(
      `Pixel Format '${pixelFormat}' is not natively supported by Skia! ` +
        `Displaying a fall-back format that might use wrong colors instead...`
    );
    lastWarn = pixelFormat;
  }
}

function getSkiaTypeForPixelFormat(pixelFormat: PixelFormat): ColorType {
  switch (pixelFormat) {
    case 'abgr':
    case 'argb':
      warnNotSupported(pixelFormat);
      return ColorType.RGBA_8888;
    case 'bgr':
      warnNotSupported(pixelFormat);
      return ColorType.RGB_888x;
    case 'rgb':
      return ColorType.RGB_888x;
    case 'rgba':
      return ColorType.RGBA_8888;
    case 'bgra':
      return ColorType.BGRA_8888;
  }
}
function getComponentsPerPixel(pixelFormat: PixelFormat): number {
  switch (pixelFormat) {
    case 'abgr':
    case 'rgba':
    case 'bgra':
    case 'argb':
      return 4;
    case 'rgb':
    case 'bgr':
      return 3;
  }
}

export default function App() {
  const permission = useCameraPermission();
  const device = useCameraDevice('back');
  const previewImage = useSharedValue<SkImage | null>(null);

  React.useEffect(() => {
    permission.requestPermission();
  }, [permission]);

  const plugin = useResizePlugin();

  const updatePreviewImageFromData = useRunOnJS(
    (data: SkData, pixelFormat: PixelFormat) => {
      const componentsPerPixel = getComponentsPerPixel(pixelFormat);
      const image = Skia.Image.MakeImage(
        {
          width: WIDTH,
          height: HEIGHT,
          alphaType: AlphaType.Opaque,
          colorType: getSkiaTypeForPixelFormat(pixelFormat),
        },
        data,
        WIDTH * componentsPerPixel
      );

      previewImage.value?.dispose();
      previewImage.value = image;
    },
    []
  );

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';

      const start = performance.now();

      const result = plugin.resize(frame, {
        scale: {
          width: WIDTH,
          height: HEIGHT,
        },
        dataType: TARGET_TYPE,
        pixelFormat: TARGET_FORMAT,
        rotation: '90deg',
        mirror: true,
      });

      const data = Skia.Data.fromBytes(result);
      updatePreviewImageFromData(data, TARGET_FORMAT);
      data.dispose();
      const end = performance.now();

      console.log(
        `Resized ${frame.width}x${frame.height} into 100x100 frame (${
          result.length
        }) in ${(end - start).toFixed(2)}ms`
      );
    },
    [updatePreviewImageFromData]
  );

  return (
    <View style={styles.container}>
      {permission.hasPermission && device != null && (
        <Camera
          device={device}
          enableFpsGraph
          style={StyleSheet.absoluteFill}
          isActive={true}
          pixelFormat="yuv"
          frameProcessor={frameProcessor}
        />
      )}
      <View style={styles.canvasWrapper}>
        <Canvas style={{ width: WIDTH, height: WIDTH }}>
          <Image
            image={previewImage}
            x={0}
            y={0}
            width={WIDTH}
            height={WIDTH}
            fit="cover"
          />
        </Canvas>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
  canvasWrapper: {
    position: 'absolute',
    bottom: 80,
    left: 20,
  },
});
