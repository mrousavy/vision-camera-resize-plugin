//
// Created by Thomas Coldwell on 20/08/2024.
//

#pragma once

#include <optional>
#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;
using namespace jni;


struct JMap : public JavaClass<JMap> {
    static constexpr auto kJavaDescriptor = "Ljava/util/Map;";
public:
    std::optional<std::string> getStringValue(std::string key);
    std::optional<local_ref<JMap>> getMapValue(std::string key);
    bool getBoolValue(std::string key);
    int getIntValue(std::string key);
    double getDoubleValue(std::string key);
};

} // namespace vision
