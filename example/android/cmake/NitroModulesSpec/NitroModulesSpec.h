/**
 * Minimal stub for RN app autolinking.
 *
 * react-native-nitro-modules provides a ReactPackage but does not currently
 * ship generated codegen JNI sources. RN 0.84 still generates an app-level
 * autolinking provider for its declared `codegenConfig`, so we provide the
 * expected provider symbol and let it return `nullptr`.
 */

#pragma once

#include <ReactCommon/JavaTurboModule.h>
#include <ReactCommon/TurboModule.h>
#include <jsi/jsi.h>

namespace facebook::react {

JSI_EXPORT
std::shared_ptr<TurboModule> NitroModulesSpec_ModuleProvider(
    const std::string& moduleName,
    const JavaTurboModule::InitParams& params);

} // namespace facebook::react
