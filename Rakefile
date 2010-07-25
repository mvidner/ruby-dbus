#! /usr/bin/env ruby
require 'rake'
require 'rake/gempackagetask'
require 'fileutils'
include FileUtils
require 'rake/rdoctask'
require 'rake/testtask'

desc 'Default: run tests in the proper environment'
task :default => "env:test"

def common_test_task(t)
    t.libs << "lib"
    t.test_files = FileList['test/*_test.rb', 'test/t*.rb']
    t.verbose = true
end
Rake::TestTask.new {|t| common_test_task t }

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new {|t| common_test_task t }
rescue LoadError
  # no rcov, never mind
end

%w(test rcov).each do |tname|
  namespace :env do
    desc "Run #{tname} in the proper environment"
    task tname do |t|
      cd "test" do
        system "./test_env rake #{tname}"
      end
    end
  end
end

spec = Gem::Specification.new do |s|
    s.name = "ruby-dbus"
    s.version = "0.3.1"
    s.author = "Ruby DBus Team"
    s.email = "ruby-dbus-devel@lists.luon.net"
    s.homepage = "http://trac.luon.net/data/ruby-dbus/"
    s.platform = Gem::Platform::RUBY
    s.summary = "Ruby module for interaction with DBus"
    s.files = FileList["{doc/tutorial/src,examples,lib,test}/**/*", "setup.rb"].to_a.sort
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
