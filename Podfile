# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

source 'https://cdn.cocoapods.org/'
source 'https://github.com/TheraForge/OTFCocoapodSpecs'

target 'OTFCloudantStore' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '14.6'
  pod 'OTFCloudClientAPI', '1.0.5-beta'
  pod 'OTFCDTDatastore', '2.1.1-beta.5'
  pod 'OTFCareKitStore/CareHealth', '2.0.2-beta.5'
  pod 'OTFUtilities', '1.0.2-beta'

  target 'OTFCloudantStoreWatch' do
    use_frameworks!
    platform :watchos, '8.0'
    pod 'OTFCloudClientAPI', '1.0.5-beta'
    pod 'OTFCDTDatastore', '2.1.1-beta.5'
    pod 'OTFCareKitStore/CareHealth', '2.0.2-beta.5'
  end
  
  target 'OTFCloudantStoreTests' do
 #     inherit! :search_paths
      use_frameworks!
      pod 'OTFCloudClientAPI', '1.0.5-beta'
      pod 'OTFCDTDatastore', '2.1.1-beta.5'
      pod 'OTFCareKitStore/CareHealth', '2.0.2-beta.5'
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '8.0'
    end
  end
end
