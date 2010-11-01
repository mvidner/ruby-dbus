# -*- ruby -*-
require "rubygems"
require "rake"

GEMSPEC = Gem::Specification.new do |s|
  s.name = "ruby-dbus"
  # s.rubyforge_project = nil
  s.summary = "Ruby module for interaction with D-Bus"
  # s.description = FIXME
  s.version = File.read("VERSION").strip
  s.author = "Ruby DBus Team"
  s.email = "ruby-dbus-devel@lists.luon.net"
  s.homepage = "http://trac.luon.net/data/ruby-dbus/"
  s.files = FileList["{doc/tutorial,examples,lib,test}/**/*", "Rakefile", "ruby-dbus.gemspec", "VERSION"].to_a.sort
  s.require_path = "lib"
  s.has_rdoc = true
  s.extra_rdoc_files = ["COPYING", "README", "NEWS"]
end
