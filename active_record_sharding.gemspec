# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_record_sharding/version'

Gem::Specification.new do |spec|
  spec.name          = "active_record_sharding"
  spec.version       = ActiveRecordSharding::VERSION
  spec.authors       = ["hirocaster"]
  spec.email         = ["hohtsuka@gmail.com"]
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "pry"
  # spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency"parallel"
  spec.add_development_dependency "awesome_print"

  spec.add_dependency "activerecord", ">= 4.2"
  spec.add_dependency "activesupport", ">= 4.2"
  spec.add_dependency "memoist"
  spec.add_dependency "mysql2"
  spec.add_dependency "request_store"
end
