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
    std::optional<std::string> getStringValue(alias_ref<JString> key);
    std::optional<local_ref<JMap>> getMapValue(alias_ref<JString> key);
    bool getBoolValue(alias_ref<JString> key);
    int getIntValue(alias_ref<JString> key);
    double getDoubleValue(alias_ref<JString> key);
};

} // namespace vision
