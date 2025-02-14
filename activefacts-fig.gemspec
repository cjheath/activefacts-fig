# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'activefacts/fig/version'

Gem::Specification.new do |spec|
  spec.name          = "activefacts-fig"
  spec.version       = ActiveFacts::FIG::VERSION
  spec.authors       = ["Clifford Heath"]
  spec.email         = ["clifford.heath@gmail.com"]

  spec.summary       = %q{FIG format importer and generator for the ActiveFacts fact modeling suite.}
  spec.description   = %q{FIG format importer and generator for the ActiveFacts fact modeling suite.}
  spec.homepage      = "http://github.com/cjheath/activefacts-fig"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.
    split("\x0").
    reject { |f| f.match(%r{^(test|spec|features)/}) }.
    map{|file| file.sub(/\.treetop$/,'.rb')}
  spec.bindir        = "exe"
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", ">= 1.10"
  spec.add_development_dependency "rake", ">= 10"
  spec.add_development_dependency "rspec", "~> 3.3"
  spec.add_development_dependency "debug"

  spec.add_runtime_dependency "activefacts-metamodel", ">= 1.9.11", "~> 1"
  spec.add_runtime_dependency "activefacts-compositions", ">= 1.9.23", "~> 1"
  spec.add_runtime_dependency "treetop", ["~> 1.6", ">= 1.6.9"]
end
