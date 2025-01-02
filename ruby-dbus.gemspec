# frozen_string_literal: true

# -*- ruby -*-
require "rubygems"

GEMSPEC = Gem::Specification.new do |s|
  s.name = "ruby-dbus"
  # s.rubyforge_project = nil
  s.summary = "Ruby module for interaction with D-Bus"
  s.description = "Pure Ruby module for interaction with D-Bus IPC system"
  s.version = File.read("VERSION").strip
  s.license = "LGPL-2.1-or-later"
  s.author = "Ruby DBus Team"
  s.email = "martin.github@vidner.net"
  s.homepage = "https://github.com/mvidner/ruby-dbus"
  s.files = Dir[
    "{doc,examples,lib,spec}/**/*",
    "COPYING", "NEWS.md", "Rakefile", "README.md",
    "ruby-dbus.gemspec", "VERSION", ".rspec"
  ]
  s.require_path = "lib"

  s.required_ruby_version = ">= 2.4.0"

  # Either of rexml and nokogiri is required
  # but AFAIK gemspec cannot express that.
  # Nokogiri is recommended as rexml is dead slow.
  s.add_runtime_dependency "rexml"
  # s.add_runtime_dependency "nokogiri"

  # workaround: rubocop-1.0 needs base64 which is no longer in stdlib in newer rubies
  s.add_development_dependency "base64"
  s.add_development_dependency "packaging_rake_tasks"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 3"
  s.add_development_dependency "rubocop", "= 1.0"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "simplecov-lcov"
end
