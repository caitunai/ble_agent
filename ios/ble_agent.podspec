#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint ble_agent.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'ble_agent'
  s.version          = '1.0.1'
  s.summary          = 'Flutter SDK for BLE device management and translation services.'
  s.description      = <<-DESC
Flutter SDK for BLE device management and translation services, providing device scanning, connection, voice recognition and translation features.
                       DESC
  s.homepage         = 'https://github.com/caitun/ble_agent'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Caitun' => 'dev@caitun.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'ble_agent/Sources/ble_agent/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.6'
  
  # Privacy Manifest
  s.resource_bundles = {
    'ble_agent_privacy' => ['ble_agent/Sources/ble_agent/PrivacyInfo.xcprivacy']
  }

  # Flutter Framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_XCFRAMEWORKS_BUILD_DIR)/ble_agent'
  }
  s.user_target_xcconfig = {
    'FRAMEWORK_SEARCH_PATHS' => '$(inherited) $(PODS_XCFRAMEWORKS_BUILD_DIR)/ble_agent'
  }
  s.swift_version = '5.0'

  # 三个独立的 xcframework
  s.vendored_frameworks = [
    'ble_agent/Frameworks/CaitunBleAgent.xcframework',
    'ble_agent/Frameworks/JLAudioUnitKit.xcframework',
    'ble_agent/Frameworks/Opus.xcframework'
  ]

  # 添加依赖的系统框架
  s.frameworks = 'CoreBluetooth', 'AudioToolbox', 'AVFoundation', 'CoreAudio'
end
