# Contributing

Contributions are always welcome, no matter how large or small!

We want this community to be friendly and respectful to each other. Please follow it in all your interactions with the project. Before contributing, please read the [code of conduct](./CODE_OF_CONDUCT.md).

## Development workflow

This repository contains:

- The library package in the root directory.
- An example app in the `example/` directory.

To get started, install dependencies in both projects:

```sh
yarn
cd example && yarn
```

The [example app](/example/) demonstrates usage of the library. You need to run it to test any changes you make.

It is configured to use the local version of the library, so any changes you make to the library's source code will be reflected in the example app. Changes to the library's JavaScript code will be reflected in the example app without a rebuild, but native code changes will require a rebuild of the example app.

If you want to use Android Studio or XCode to edit the native code, you can open the `example/android` or `example/ios` directories respectively in those editors. To edit the Objective-C or Swift files, open `example/ios/VisionCameraResizePluginExample.xcworkspace` in XCode and find the source files at `Pods > Development Pods > vision-camera-resize-plugin`.

To edit the Java or Kotlin files, open `example/android` in Android studio and find the source files at `vision-camera-resize-plugin` under `Android`.

Use the root package for library generation/build tasks:

```sh
yarn specs
yarn build
yarn typecheck
yarn lint
yarn check-all
```

Use the example app directory for runtime testing:

```sh
cd example
yarn start
```

Run the example app on Android:

```sh
yarn android
```

Run the example app on iOS:

```sh
yarn ios
```

If you change native iOS code, reinstall pods:

```sh
cd example/ios
pod install
```

For CI-style local builds, use:

```sh
yarn build
cd example && yarn build:android
cd example && yarn build:ios
```

To fix formatting errors, run the following:

```sh
yarn lint --fix
./scripts/ktlint.sh
./scripts/clang-format.sh
```

### Commit message convention

We follow the [conventional commits specification](https://www.conventionalcommits.org/en) for our commit messages:

- `fix`: bug fixes, e.g. fix crash due to deprecated method.
- `feat`: new features, e.g. add new method to the module.
- `refactor`: code refactor, e.g. migrate from class components to hooks.
- `docs`: changes into documentation, e.g. add usage example for the module..
- `test`: adding or updating tests, e.g. add integration tests using detox.
- `chore`: tooling changes, e.g. change CI config.

Our pre-commit hooks verify that your commit message matches this format when committing.

### Linting and tests

[ESLint](https://eslint.org/), [Prettier](https://prettier.io/), [TypeScript](https://www.typescriptlang.org/)

We use TypeScript for type checking, ESLint with Prettier for JS/TS linting, `ktlint` for Kotlin formatting, and `clang-format` for C++ formatting.

There is currently no dedicated automated unit test suite in this repository, so verify changes by building the library and running the example app on iOS and Android.

### Publishing to npm

We use [release-it](https://github.com/release-it/release-it) to make it easier to publish new versions. It handles common tasks like bumping version based on semver, creating tags and releases etc.

To publish new versions, run the following:

```sh
yarn release
```

### Scripts

The `package.json` file contains various scripts for common tasks:

- `yarn specs`: generate Nitro bindings.
- `yarn build`: generate specs and build the package.
- `yarn typecheck`: type-check files with TypeScript.
- `yarn lint`: lint JS/TS files with ESLint.
- `yarn check-all`: run Kotlin/C++ formatting plus JS/TS checks.
- `cd example && yarn start`: start Metro for the example app.
- `cd example && yarn android`: run the example app on Android.
- `cd example && yarn ios`: run the example app on iOS.

### Sending a pull request

> **Working on your first pull request?** You can learn how from this _free_ series: [How to Contribute to an Open Source Project on GitHub](https://app.egghead.io/playlists/how-to-contribute-to-an-open-source-project-on-github).

When you're sending a pull request:

- Prefer small pull requests focused on one change.
- Verify that linters and tests are passing.
- Review the documentation to make sure it looks good.
- Follow the pull request template when opening a pull request.
- For pull requests that change the API or implementation, discuss with maintainers first by opening an issue.
