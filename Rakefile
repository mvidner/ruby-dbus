require 'rake'
require 'rake/gempackagetask'
require 'fileutils'
include FileUtils

spec = Gem::Specification.new do |s|
    s.name = "dbus"
    s.version = "0.2.1"
    s.author = "Ruby DBUS Team"
    s.email = "http://trac.luon.net"
    s.homepage = "http://trac.luon.net/data/ruby-dbus/"
    s.platform = Gem::Platform::RUBY
    s.summary = "Ruby module for interaction with dbus"
    s.files = FileList["{examples,lib}/**/*"].to_a
    s.require_path = "lib"
    s.autorequire = "dbus"
    s.has_rdoc = true
    s.extra_rdoc_files = ["ChangeLog", "COPYING", "README", "NEWS"]
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = false
end
