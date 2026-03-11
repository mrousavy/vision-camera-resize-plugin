# vision-camera-resize-plugin

A Nitro module for fast [React Native VisionCamera](https://github.com/mrousavy/react-native-vision-camera) v5 frame resizing, cropping, rotation, mirroring, and pixel-format conversion.

This release is built for VisionCamera v5 and Nitro. There is no manual frame processor plugin registration, and the old `createResizePlugin()` / `useResizePlugin()` API has been removed.

## Requirements

- `react-native-vision-camera@^5.0.0-beta.6`
- `react-native-nitro-modules@^0.35.0`
- `react-native-worklets@0.7.x`
- React Native `0.84.x`
- React `19.x`
- iOS 15.1+
- Android minSdk 24+

## Installation

Install the library and its peer dependencies:

```sh
yarn add vision-camera-resize-plugin react-native-vision-camera@^5.0.0-beta.6 react-native-nitro-modules@^0.35.0
yarn add react-native-worklets@0.7.4
```

Then install iOS pods:

```sh
cd ios && pod install
```

Make sure your Babel config uses the Worklets plugin:

```js
module.exports = {
  presets: ['module:@react-native/babel-preset'],
  plugins: ['react-native-worklets/plugin'],
}
```

## Usage

Import the singleton and call `resize()` directly from a VisionCamera v5 frame output callback:

```tsx
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameOutput,
} from 'react-native-vision-camera'
import { VisionCameraResizePlugin } from 'vision-camera-resize-plugin'

const frameOutput = useFrameOutput({
  pixelFormat: 'yuv',
  onFrame(frame) {
    'worklet'

    try {
      const resized = VisionCameraResizePlugin.resize(frame, {
        scale: {
          width: 192,
          height: 192,
        },
        pixelFormat: 'rgb',
        dataType: 'uint8',
        rotation: '0deg',
        mirror: frame.isMirrored,
      })

      const firstPixel = {
        r: resized[0],
        g: resized[1],
        b: resized[2],
      }

      console.log(firstPixel)
    } finally {
      frame.dispose()
    }
  },
})

function App() {
  const device = useCameraDevice('back')
  const permission = useCameraPermission()

  return device != null && permission.hasPermission ? (
    <Camera device={device} isActive={true} outputs={[frameOutput]} />
  ) : null
}
```

`resize()` returns a typed array based on `dataType`:

- `uint8` -> `Uint8Array`
- `float32` -> `Float32Array`

## API

```ts
type Rotation = '0deg' | '90deg' | '180deg' | '270deg'
type DataType = 'uint8' | 'float32'
type PixelFormat = 'rgb' | 'rgba' | 'argb' | 'bgra' | 'bgr' | 'abgr'

interface Size {
  width: number
  height: number
}

interface Rect extends Size {
  x: number
  y: number
}

interface Options<T extends DataType> {
  mirror?: boolean
  crop?: Rect
  scale?: Size
  rotation?: Rotation
  pixelFormat: PixelFormat
  dataType: T
}

VisionCameraResizePlugin.resize<T extends DataType>(
  frame: Frame,
  options: Options<T>
): T extends 'uint8' ? Uint8Array : Float32Array
```

## Behavior

- `scale` resizes the frame to the target dimensions.
- `crop` selects a source rect before conversion/scaling.
- If `scale` is set without `crop`, the plugin performs an implicit center crop to preserve aspect ratio.
- `rotation` accepts `0deg`, `90deg`, `180deg`, or `270deg`.
- `mirror` mirrors the output horizontally.
- Conversion happens in native code on both iOS and Android.

## Pixel Formats

The output operates in RGB color space:

| Format | Byte layout |
| --- | --- |
| `rgb` | `R G B` |
| `rgba` | `R G B A` |
| `argb` | `A R G B` |
| `bgra` | `B G R A` |
| `bgr` | `B G R` |
| `abgr` | `A B G R` |

## Data Types

| Type | JS type | Value range |
| --- | --- | --- |
| `uint8` | `Uint8Array` | `0...255` |
| `float32` | `Float32Array` | `0.0...1.0` |

`float32` is 4x larger in memory than `uint8`. For most camera ML pipelines, `rgb`/`uint8` or `argb`/`uint8` are the cheapest formats.

## Cropping

Provide `crop` when you want explicit control over the source rect:

```ts
const resized = VisionCameraResizePlugin.resize(frame, {
  scale: {
    width: 192,
    height: 192,
  },
  crop: {
    x: 0,
    y: 0,
    width: frame.width,
    height: frame.width,
  },
  pixelFormat: 'rgb',
  dataType: 'uint8',
})
```

## Notes

- This package is a breaking major release for the Nitro migration.
- Only iOS and Android are supported.
- The resize cores remain native and optimized:
  - Android uses libyuv/C++
  - iOS uses vImage/Accelerate

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for local development and example app commands.

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
