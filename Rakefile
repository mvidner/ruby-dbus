require 'rake'
require 'rake/gempackagetask'
require 'fileutils'
include FileUtils
require 'rake/rdoctask'

spec = Gem::Specification.new do |s|
    s.name = "ruby-dbus"
    s.version = "0.2.9"
    s.author = "Ruby DBus Team"
    s.email = "ruby-dbus-devel@lists.luon.net"
    s.homepage = "http://trac.luon.net/data/ruby-dbus/"
    s.platform = Gem::Platform::RUBY
    s.summary = "Ruby module for interaction with DBus"
    s.files = FileList["{doc,examples,lib,test}/**/*", "setup.rb"].to_a.sort
    s.require_path = "lib"
    s.autorequire = "dbus"
    s.has_rdoc = true
    s.extra_rdoc_files = ["ChangeLog", "COPYING", "README", "NEWS"]
end

Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_tar = true
end

# thanks to Josh Nichols
desc "Generate a gemspec file for GitHub"
task :gemspec do
  File.open("#{spec.name}.gemspec", 'w') do |f|
    f.write spec.to_ruby
  end
end 

Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc/rdoc'
  rd.rdoc_files.include("README", "lib/**/*.rb")
#  rd.options << "--diagram"
#  rd.options << "--all"
end
