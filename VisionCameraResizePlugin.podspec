require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "VisionCameraResizePlugin"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.source       = { :git => "https://github.com/mrousavy/vision-camera-resize-plugin.git", :tag => "#{s.version}" }

  s.source_files = [
    "ios/**/*.{m,mm,swift}",
    "cpp/**/*.{hpp,cpp}",
  ]
  # Swift uses the pod's underlying Clang module, so ObjC helpers it references
  # must be exported through the umbrella header.
  s.public_header_files = [
    "ios/ResizeProcessor.h",
  ]
  s.private_header_files = [
    "ios/FrameBuffer.h",
  ]

  load "nitrogen/generated/ios/VisionCameraResizePlugin+autolinking.rb"
  add_nitrogen_files(s)

  s.dependency "VisionCamera"
  s.dependency "React-jsi"
  s.dependency "React-callinvoker"
  install_modules_dependencies(s)
end
