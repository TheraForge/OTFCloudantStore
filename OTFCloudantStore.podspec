#
# Be sure to run `pod lib lint OTFCloudantStores.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'OTFCloudantStore'
  s.version          = '2.0.0'
  s.summary          = 'TheraForge OTFCloudantStore uses OTFCDTDatastore to store the data.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.homepage         = 'https://github.com/TheraForge/OTFCloudantStore'
  s.license          = { :type => 'BSD-4', :file => 'LICENSE.md' }
  s.author           = { 'Hippocrates Technologies' => 'hippocratestech-dev@googlegroups.com' }
  s.source           = { :git => 'https://github.com/TheraForge/OTFCloudantStore.git', :tag => s.version.to_s }

  s.ios.deployment_target = '16.0'
  s.watchos.deployment_target = '9.0'

  s.source_files = 'OTFCloudantStore/Classes/**/*'
  s.default_subspec = 'CloudantOnly'
  s.dependency 'OTFCDTDatastore', '2.1.1-tf.2'
  s.dependency 'OTFCloudClientAPI', '2.0.0'
  s.dependency 'OTFUtilities', '2.0.0'

  s.subspec 'CloudantOnly' do |ss|
    ss.name = 'CloudantOnly'
    ss.source_files = 'OTFCloudantStore/Classes/**/*'
    ss.pod_target_xcconfig = { 
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) CLOUDANT'
    }
    ss.dependency 'OTFCDTDatastore', '2.1.1-tf.2'
  end

  s.subspec 'CloudantCare' do |ss|
    ss.name = "CloudantCare"
    ss.source_files = 'OTFCloudantStore/Classes/**/*'
    ss.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) CARE'
    }
    ss.dependency 'OTFCareKitStore/Care', '2.0.2-tf.2'
    ss.dependency 'OTFCDTDatastore', '2.1.1-tf.2'
  end

  s.subspec 'CloudantCareHealth' do |ss|
    ss.name = "CloudantCareHealth"
    ss.source_files = 'OTFCloudantStore/Classes/**/*'
    ss.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) CARE HEALTH'
    }
    ss.dependency 'OTFCareKitStore/CareHealth', '2.0.2-tf.2'
    ss.dependency 'OTFCDTDatastore', '2.1.1-tf.2'
  end

  s.subspec 'CloudantHealth' do |ss|
    ss.name = "CloudantHealth"
    ss.source_files = 'OTFCloudantStore/Classes/**/*'
    ss.pod_target_xcconfig = {
      'SWIFT_ACTIVE_COMPILATION_CONDITIONS' => '$(inherited) HEALTH'
    }
    ss.dependency 'OTFCDTDatastore', '2.1.1-tf.2'
  end
end

