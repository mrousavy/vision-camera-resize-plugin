//
// Created by Thomas Coldwell on 20/08/2024.
//

#include "JMap.h"
#include <fbjni/fbjni.h>
#include <jni.h>

namespace vision {

using namespace facebook;
using namespace jni;


std::optional<std::string> JMap::getStringValue(std::string key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), make_jstring(key));
    if (!result->isInstanceOf(JString::javaClassStatic())) {
        return std::nullopt;
    }
    return std::optional<std::string>(static_ref_cast<JString>(result)->toStdString());
}

std::optional<local_ref<JMap>> JMap::getMapValue(std::string key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), make_jstring(key));
    if (!result->isInstanceOf(JMap::javaClassStatic())) {
        return std::nullopt;
    }
    return std::optional<local_ref<JMap>>(static_ref_cast<JMap>(result));
}

bool JMap::getBoolValue(std::string key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), make_jstring(key));
    if (!result->isInstanceOf(JBoolean::javaClassStatic())) {
        return false;
    }
    return static_ref_cast<JBoolean>(result)->booleanValue();
}

int JMap::getIntValue(std::string key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), make_jstring(key));
    if (!result->isInstanceOf(JInteger::javaClassStatic())) {
        return 0;
    }
    return static_ref_cast<JInteger>(result)->intValue();
}

double JMap::getDoubleValue(std::string key) {
    auto method = getClass()->getMethod<JObject(alias_ref<JObject>)>("get");
    auto result = method(self(), make_jstring(key));
    if (!result->isInstanceOf(JDouble::javaClassStatic())) {
        return 0.0;
    }
    return static_ref_cast<JDouble>(result)->doubleValue();
}

} // namespace vision
