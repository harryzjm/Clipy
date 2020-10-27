platform :osx, '10.13'
use_frameworks!
inhibit_all_warnings!

source 'https://github.com/CocoaPods/Specs.git'

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