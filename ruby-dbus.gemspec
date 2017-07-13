# -*- ruby -*-
require "rubygems"

GEMSPEC = Gem::Specification.new do |s|
  s.name = "ruby-dbus"
  # s.rubyforge_project = nil
  s.summary = "Ruby module for interaction with D-Bus"
  s.description = "Pure Ruby module for interaction with D-Bus IPC system"
  s.version = File.read("VERSION").strip
  s.license = "LGPL v2.1"
  s.author = "Ruby DBus Team"
  s.email = "ruby-dbus-devel@lists.luon.net"
  s.homepage = "https://trac.luon.net/ruby-dbus"
  s.files = Dir[
    "{doc,examples,lib,spec}/**/*",
    "COPYING", "NEWS.md", "Rakefile", "README.md",
    "ruby-dbus.gemspec", "VERSION", ".rspec"
  ]
  s.require_path = "lib"

  s.required_ruby_version = ">= 2.0.0"

  # This is optional
  # s.add_runtime_dependency "nokogiri"

  s.add_development_dependency "coveralls"
  s.add_development_dependency "packaging_rake_tasks"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 3"
  s.add_development_dependency "rubocop", "= 0.41.2"
  s.add_development_dependency "simplecov"
end
