// https://github.com/react-native-community/cli/blob/main/docs/dependencies.md

module.exports = {
  dependency: {
    platforms: {
      ios: {
        podspecPath: 'VisionCameraResizePlugin.podspec',
      },
      android: {
        sourceDir: './android',
        packageImportPath:
          'import com.margelo.nitro.visioncameraresizeplugin.VisionCameraResizePluginPackage;',
        packageInstance: 'new VisionCameraResizePluginPackage()',
      },
    },
  },
}
