platform :osx, '10.15'
use_frameworks!
inhibit_all_warnings!

target 'Clipy' do
  
  # Application
  pod 'RealmSwift'
  pod 'RxCocoa'
  pod 'RxSwift'
  pod 'RxOptional'
  pod 'RxScreeen'
  
  pod 'Sauce'
  pod 'LoginServiceKit', :git => 'https://github.com/Clipy/LoginServiceKit.git'
  
  pod 'PINCache'
  pod 'Sparkle'
  pod 'KeyHolder'
  pod 'AEXML'
  pod 'LetsMove'
  pod 'SwiftHEXColors'

  # Utility
  pod 'BartyCrouch'
  pod 'SwiftLint'
  pod 'SwiftGen'
  
  target 'ClipyTests' do
    inherit! :search_paths
    
    pod 'Quick'
    pod 'Nimble'
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      version=config.build_settings['MACOSX_DEPLOYMENT_TARGET'].split(".")
      if version.first.to_f == 10 and version.last.to_f < 15
        config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '10.15'
      end
    end
  end
end
