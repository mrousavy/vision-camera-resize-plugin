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
  Image,
  SkData,
  Canvas,
  SkImage,
} from '@shopify/react-native-skia';
import { useRunOnJS } from 'react-native-worklets-core';
import { createSkiaImageFromData } from './SkiaUtils';

type PixelFormat = Options<'uint8'>['pixelFormat'];

const WIDTH = 300;
const HEIGHT = 300;
const TARGET_TYPE = 'uint8' as const;
const TARGET_FORMAT: PixelFormat = 'rgba';

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
      const image = createSkiaImageFromData(data, WIDTH, HEIGHT, pixelFormat);
      if (image == null) {
        data.dispose();
        return;
      }
      previewImage.value?.dispose();
      previewImage.value = image;
      data.dispose();
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
      const end = performance.now();

      console.log(
        `Resized ${frame.width}x${frame.height} into ${WIDTH}x${HEIGHT} frame (${
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
        <Canvas style={{ width: WIDTH, height: HEIGHT }}>
          <Image
            image={previewImage}
            x={0}
            y={0}
            width={WIDTH}
            height={HEIGHT}
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
    borderColor: '#F00',
    borderWidth: 2,
  },
});
