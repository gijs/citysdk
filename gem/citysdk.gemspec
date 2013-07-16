# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'citysdk'

Gem::Specification.new do |gem|
  gem.name          = "citysdk"
  gem.version       = CitySDK::VERSION
  gem.authors       = ["Tom Demeyer"]
  gem.email         = ["tom@waag.org"]
  gem.description   = %q{Encapsulates the CitySDK api.}
  gem.summary       = %q{Encapsulates the CitySDK api, provides high-level file import functionality.}
  gem.homepage      = "http://citysdk.waag.org"
  gem.licenses      = ['MIT']
  
  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}) { |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  
  gem.add_dependency('dbf')
  gem.add_dependency('georuby', '>= 2.0.0')
  gem.add_dependency('faraday', '>= 0.8.5')
  gem.add_dependency('charlock_holmes', '>= 0.6.9.4')
  
  gem.add_development_dependency "rspec"
end

