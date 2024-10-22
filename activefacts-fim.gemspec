# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activefacts/fim/version'

Gem::Specification.new do |spec|
  spec.name          = "activefacts-fim"
  spec.version       = ActiveFacts::FIM::VERSION
  spec.authors       = ["Clifford Heath"]
  spec.email         = ["clifford.heath@gmail.com"]

  spec.summary       = %q{FIM format importer and generator for the ActiveFacts fact modeling suite.}
  spec.description   = %q{FIM format importer and generator for the ActiveFacts fact modeling suite.}
  spec.homepage      = "http://github.com/cjheath/activefacts-fim"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "rake", ">= 10"
  spec.add_development_dependency "rspec", "~> 3.3"

  spec.add_runtime_dependency "activefacts-metamodel", ">= 1.8", "~> 1"
  spec.add_runtime_dependency "nokogiri", ">= 1.6", "~> 1"
end
