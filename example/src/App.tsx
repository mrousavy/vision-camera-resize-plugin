import * as React from 'react'
import { StyleSheet, View } from 'react-native'
import {
  Camera,
  type Orientation,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
} from 'react-native-vision-camera'
import {
  type Options,
  VisionCameraResizePlugin,
} from 'vision-camera-resize-plugin'
import { useSharedValue } from 'react-native-reanimated'
import { Canvas, Image, SkData, Skia, SkImage } from '@shopify/react-native-skia'
import { runOnJS } from 'react-native-worklets'

import { createSkiaImageFromData } from './SkiaUtils'

type PixelFormat = Options<'uint8'>['pixelFormat']

const WIDTH = 480
const HEIGHT = 640
const TARGET_TYPE = 'uint8' as const
const TARGET_FORMAT: PixelFormat = 'rgba'

function getRotation(orientation: Orientation): Options<'uint8'>['rotation'] {
  switch (orientation) {
    case 'up':
      return '0deg'
    case 'right':
      return '90deg'
    case 'down':
      return '180deg'
    case 'left':
      return '270deg'
  }
}

export default function App() {
  const permission = useCameraPermission()
  const device = useCameraDevice('back')
  const previewImage = useSharedValue<SkImage | null>(null)

  React.useEffect(() => {
    permission.requestPermission()
  }, [permission])

  const updatePreviewImage = React.useCallback(
    (buffer: ArrayBufferLike, pixelFormat: PixelFormat) => {
      const data = Skia.Data.fromBytes(new Uint8Array(buffer))
      const image = createSkiaImageFromData(data as SkData, WIDTH, HEIGHT, pixelFormat)
      previewImage.value?.dispose()
      previewImage.value = image
      data.dispose()
    },
    [previewImage]
  )

  const frameOutput = useFrameOutput({
    pixelFormat: 'yuv',
    onFrame(frame) {
      'worklet'

      const start = performance.now()

      try {
        const result = VisionCameraResizePlugin.resize(frame, {
          scale: {
            width: WIDTH,
            height: HEIGHT,
          },
          dataType: TARGET_TYPE,
          pixelFormat: TARGET_FORMAT,
          rotation: getRotation(frame.orientation),
          mirror: frame.isMirrored,
        })

        runOnJS(updatePreviewImage)(result.buffer, TARGET_FORMAT)

        const end = performance.now()
        console.log(
          `Resized ${frame.width}x${frame.height} into ${WIDTH}x${HEIGHT} frame (${result.length}) in ${(end - start).toFixed(2)}ms`
        )
      } finally {
        frame.dispose()
      }
    },
  })

  return (
    <View style={styles.container}>
      {permission.hasPermission && device != null && (
        <Camera
          device={device}
          style={StyleSheet.absoluteFill}
          isActive={true}
          outputs={[frameOutput]}
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
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  canvasWrapper: {
    position: 'absolute',
    bottom: 80,
    left: 20,
  },
})
