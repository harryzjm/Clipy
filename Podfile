platform :osx, '11.0'
use_frameworks!
inhibit_all_warnings!

target 'Clipy' do
  pod 'RealmSwift'
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
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      version = config.build_settings['MACOSX_DEPLOYMENT_TARGET']
      if version.nil?
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      elsif version.split(".").first.to_f < 11
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      end

      xcconfig_path = config.base_configuration_reference.real_path
      xcconfig = File.read(xcconfig_path)
      xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
      File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
    end
  end
end
