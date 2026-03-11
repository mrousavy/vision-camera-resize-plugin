import { NitroModules } from 'react-native-nitro-modules';
const resizePlugin = NitroModules.createHybridObject('ResizePlugin');
function getRotationDegrees(rotation) {
    switch (rotation) {
        case undefined:
            return undefined;
        case '0deg':
            return 0;
        case '90deg':
            return 90;
        case '180deg':
            return 180;
        case '270deg':
            return 270;
    }
}
function resize(frame, options) {
    'worklet';
    const nativeOptions = {
        ...options,
        rotationDegrees: getRotationDegrees(options.rotation),
    };
    const arrayBuffer = resizePlugin.resize(frame, nativeOptions);
    switch (options.dataType) {
        case 'uint8':
            return new Uint8Array(arrayBuffer);
        case 'float32':
            return new Float32Array(arrayBuffer);
        default:
            throw new Error(`Invalid data type (${options.dataType})!`);
    }
}
export const VisionCameraResizePlugin = {
    resize,
};
