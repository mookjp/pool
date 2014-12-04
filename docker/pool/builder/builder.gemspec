# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'builder/version'

Gem::Specification.new do |spec|
  spec.name          = "builder"
  spec.version       = Builder::VERSION
  spec.authors       = ["Mook"]
  spec.email         = ["mookjpy@gmail.com"]
  spec.summary       = %q{builder for mookjp/pool}
  spec.description   = %q{builder for mookjp/pool}
  spec.homepage      = "https://github.com/mookjp/pool"
  spec.license       = "MIT"

  spec.files         = `find * -type f -print0`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "eventmachine"
  spec.add_runtime_dependency "em-websocket"
  spec.add_runtime_dependency "eventmachine_httpserver"
  spec.add_runtime_dependency "git"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "pry-nav"
  spec.add_development_dependency "pry-remote"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-nc"
  spec.add_development_dependency "simplecov"
end
