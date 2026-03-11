#include "NitroModulesSpec.h"

namespace facebook::react {

std::shared_ptr<TurboModule> NitroModulesSpec_ModuleProvider(
    const std::string& moduleName,
    const JavaTurboModule::InitParams& params) {
  (void)moduleName;
  (void)params;
  return nullptr;
}

} // namespace facebook::react
