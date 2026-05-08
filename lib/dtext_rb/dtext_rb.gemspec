# frozen_string_literal: true

require_relative "lib/dtext/version"

Gem::Specification.new do |spec|
  spec.name = "dtext_rb"
  spec.version = DText::VERSION
  spec.authors = %w[r888888888 evazion earlopain donovan_dmc]

  spec.summary = "DText Parser"
  spec.homepage = "https://github.com/GayFurCity/GayFurCity/tree/master/lib/dtext_rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"
  spec.extensions = ["ext/dtext/extconf.rb"]

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = %w[
    lib/dtext.rb
    lib/dtext/dtext.so
    lib/dtext/version.rb
  ]

  spec.add_development_dependency("minitest", ["~> 5.15"])
  spec.add_development_dependency("rake", ["~> 13"])
  spec.add_development_dependency("rake-compiler", ["~> 1.1"])
  spec.add_development_dependency("cgi", ["~> 0.3"])
  spec.add_development_dependency("benchmark-ips", ["~> 2.10"])
  spec.add_development_dependency("nokogiri", ["~> 1"])
end
