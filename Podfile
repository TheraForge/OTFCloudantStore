# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'

source 'https://cdn.cocoapods.org/'
source 'https://github.com/TheraForge/OTFCocoapodSpecs'

target 'OTFCloudantStore' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  platform :ios, '16.0'
  pod 'OTFCloudClientAPI', '2.0.0'
  pod 'OTFCDTDatastore', '2.1.1-tf.2'
  pod 'OTFCareKitStore/CareHealth', '2.0.2-tf.2'
  pod 'OTFUtilities', '2.0.0'

  target 'OTFCloudantStoreWatch' do
    use_frameworks!
    platform :watchos, '9.0'
    pod 'OTFCloudClientAPI', '2.0.0'
    pod 'OTFCDTDatastore', '2.1.1-tf.2'
    pod 'OTFCareKitStore/CareHealth', '2.0.2-tf.2'
  end
  
  target 'OTFCloudantStoreTests' do
 #     inherit! :search_paths
      use_frameworks!
      pod 'OTFCloudClientAPI', '2.0.0'
      pod 'OTFCDTDatastore', '2.1.1-tf.2'
      pod 'OTFCareKitStore/CareHealth', '2.0.2-tf.2'
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = '9.0'
    end
  end
end
