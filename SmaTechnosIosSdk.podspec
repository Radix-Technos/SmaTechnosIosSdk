#
# Be sure to run `pod lib lint SmaTechnosIosSdk.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'SmaTechnosIosSdk'
  s.version          = '2.0.0'
  s.summary          = 'UTE frameworks.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = 'UTE frameworks.'

  s.homepage         = 'https://github.com/Radix-Technos'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  # s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { "Your Name" => "yourname@email.com" }
  s.source           = { :git => 'https://github.com/Radix-Technos', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.0'
  # s.swift_version = '5.0'
  
  # 上传源文件
  s.source_files = '**/*.{h,m,swift}'
  
  # s.resource_bundles = {
  #   'Pod' => ['Pod/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
   s.frameworks = 'UIKit', 'Foundation', 'CoreBluetooth'
  #  s.libraries  = 'sqlite3.0'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency "iOSDFULibrary"
  
end
