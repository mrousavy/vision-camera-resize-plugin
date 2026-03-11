const path = require('path');
const libraryPackage = require('../package.json');

module.exports = {
  project: {
    android: {
      packageName: 'com.visioncameraresizepluginexample',
    },
  },
  dependencies: {
    [libraryPackage.name]: {
      root: path.join(__dirname, '..'),
      platforms: {
        ios: {
          podspecPath: path.join(
            __dirname,
            '..',
            'VisionCameraResizePlugin.podspec'
          ),
        },
        android: {
          sourceDir: path.join(__dirname, '..', 'android'),
          packageImportPath:
            'import com.margelo.nitro.visioncameraresizeplugin.VisionCameraResizePluginPackage;',
          packageInstance: 'new VisionCameraResizePluginPackage()',
        },
      },
    },
    'react-native-nitro-modules': {
      platforms: {
        android: {
          cmakeListsPath: path.join(
            __dirname,
            'android',
            'cmake',
            'NitroModulesSpec',
            'CMakeLists.txt'
          ),
        },
      },
    },
  },
};
