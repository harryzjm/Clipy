platform :osx, '14.0'
use_frameworks!
inhibit_all_warnings!

target 'Clipy' do
  pod 'MMKV'
  pod 'WCDB.swift'
  
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'RxOptional'
  pod 'RxScreeen'
  
  pod 'Sauce'
  
  pod 'PINCache'
  pod 'KeyHolder'

  pod 'LetsMove'

  pod 'SwiftLint'
  pod 'SwiftGen'

  target 'ClipyTests' do
    # Search paths only: ClipyTests is hosted inside Clipy.app (TEST_HOST), so the
    # pods it links against are already loaded in-process there. Re-embedding them
    # here would just duplicate symbols already provided by the host.
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      version = config.build_settings['MACOSX_DEPLOYMENT_TARGET']
      if version.nil?
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
      elsif version.split(".").first.to_f < 14
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '14.0'
      end

      xcconfig_path = config.base_configuration_reference.real_path
      xcconfig = File.read(xcconfig_path)
      xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
      File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
    end
  end
end
