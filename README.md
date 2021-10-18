# :warning: work in progress! :warning:

# vision-camera-resize-plugin

A [VisionCamera](https://github.com/cuvent/react-native-vision-camera) Frame Processor Plugin for fast buffer resizing.

By resizing buffers to a smaller resolution, you can achieve much faster frame processor executions than by running AI on a full-sized (4k) buffer.

## Installation

```sh
npm install vision-camera-resize-plugin
cd ios && pod install
```

Add the plugin to your `babel.config.js`:

```js
module.exports = {
  plugins: [
    [
      'react-native-reanimated/plugin',
      {
        globals: ['__resize'],
      },
    ],

    // ...
```

> Note: You have to restart metro-bundler for changes in the `babel.config.js` file to take effect.

## Usage

```js
import { resize } from "vision-camera-resize-plugin";

// ...

const frameProcessor = useFrameProcessor((frame) => {
  'worklet';
  if (frame.width > 1920) {
    frame = resize(frame, 1920, 1080)
  }
  // run AI on smaller buffer here
}, []);
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

MIT
