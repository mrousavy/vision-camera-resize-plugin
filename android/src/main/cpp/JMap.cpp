//
// Created by Thomas Coldwell on 20/08/2024.
//

#include "JMap.h"
#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;
using namespace jni;


std::optional<std::string> JMap::getStringValue(alias_ref<JString> key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), key);
    if (!result->isInstanceOf(JString::javaClassStatic())) {
        return std::nullopt;
    }
    return std::optional<std::string>(static_ref_cast<JString>(result)->toStdString());
}

std::optional<local_ref<JMap>> JMap::getMapValue(alias_ref<JString> key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), key);
    if (!result->isInstanceOf(JMap::javaClassStatic())) {
        return std::nullopt;
    }
    return std::optional<local_ref<JMap>>(static_ref_cast<JMap>(result));
}

bool JMap::getBoolValue(alias_ref <JString> key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), key);
    if (!result->isInstanceOf(JBoolean::javaClassStatic())) {
        return false;
    }
    return static_ref_cast<JBoolean>(result)->booleanValue();
}

int JMap::getIntValue(alias_ref <JString> key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), key);
    if (!result->isInstanceOf(JInteger::javaClassStatic())) {
        return 0;
    }
    return static_ref_cast<JInteger>(result)->intValue();
}

double JMap::getDoubleValue(alias_ref <JString> key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), key);
    if (!result->isInstanceOf(JDouble::javaClassStatic())) {
        return 0.0;
    }
    return static_ref_cast<JDouble>(result)->doubleValue();
}

} // namespace vision
