# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'norairrecord/version'

Gem::Specification.new do |spec|
  spec.name          = "norairrecord"
  spec.version       = Norairrecord::VERSION
  spec.authors       = ["nora"]
  spec.email         = ["nora@hcb.pizza"]

  spec.summary       = %q{Airtable client}
  spec.description   = %q{screwed a cookie to the tabel}
  spec.homepage      = "https://github.com/24c02/norairrecord"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.2"

  spec.add_dependency "faraday", [">= 1.0", "< 3.0"]
  spec.add_dependency "net-http-persistent"
  spec.add_dependency "faraday-net_http_persistent"

  spec.add_development_dependency "bundler", "~> 2"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
end
