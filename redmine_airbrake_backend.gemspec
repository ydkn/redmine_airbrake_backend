# coding: utf-8
$LOAD_PATH.push File.expand_path('../lib', __FILE__)

require 'redmine_airbrake_backend/version'

Gem::Specification.new do |spec|
  spec.name          = 'redmine_airbrake_backend'
  spec.version       = RedmineAirbrakeBackend::VERSION
  spec.authors       = ['Florian Schwab']
  spec.email         = ['me@ydkn.de']
  spec.description   = %q(Plugin which adds Airbrake support to Redmine)
  spec.summary       = %q(This plugin provides the necessary API to use Redmine as a Airbrake backend)
  spec.homepage      = 'https://github.com/ydkn/redmine_airbrake_backend'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'rails'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end
