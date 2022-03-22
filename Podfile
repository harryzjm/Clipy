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
  pod 'SwiftHEXColors'

  # Utility
  pod 'BartyCrouch'
  pod 'SwiftLint'
  pod 'SwiftGen'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      version=config.build_settings['MACOSX_DEPLOYMENT_TARGET'].split(".")
      if version.first.to_f < 11
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
  end
end
