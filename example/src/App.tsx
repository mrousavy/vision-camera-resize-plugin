import * as React from 'react';

import { StyleSheet, View } from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { useResizePlugin } from 'vision-camera-resize-plugin';
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

const SIZE = 256;

export default function App() {
  const permission = useCameraPermission();
  const device = useCameraDevice('back');
  const previewImg = useSharedValue<SkImage | null>(null);

  React.useEffect(() => {
    permission.requestPermission();
  }, [permission]);

  const plugin = useResizePlugin();

  const handleSkiaImage = Worklets.createRunOnJS((data: SkData) => {
    const img = Skia.Image.MakeImage(
      {
        width: SIZE,
        height: SIZE,
        alphaType: AlphaType.Opaque,
        colorType: ColorType.RGBA_8888,
      },
      data,
      SIZE * 4
    );

    previewImg.value = img;
  });

  const frameProcessor = useFrameProcessor(
    (frame) => {
      'worklet';

      const start = performance.now();

      const result = plugin.resize(frame, {
        scale: {
          width: SIZE,
          height: SIZE,
        },
        pixelFormat: 'rgba',
        dataType: 'uint8',
        rotation: '90deg',
        mirror: true,
      });

      const data = Skia.Data.fromBytes(result);

      handleSkiaImage(data);
      const end = performance.now();

      console.log(
        `Resized ${frame.width}x${frame.height} into 100x100 frame (${
          result.length
        }) in ${(end - start).toFixed(2)}ms`
      );
    },
    [handleSkiaImage]
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
        <Canvas style={{ width: SIZE, height: SIZE }}>
          <Image
            image={previewImg}
            x={0}
            y={0}
            width={SIZE}
            height={SIZE}
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
