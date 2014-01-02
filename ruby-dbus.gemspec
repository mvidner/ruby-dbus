# -*- ruby -*-
require "rubygems"
require "rake"

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
  s.files = FileList["{doc,examples,lib,test}/**/*", "COPYING", "NEWS", "Rakefile", "README.md", "ruby-dbus.gemspec", "VERSION"].to_a.sort
  s.require_path = "lib"
  s.required_ruby_version = ">= 1.9.3"
  s.add_development_dependency("packaging_rake_tasks")
end
