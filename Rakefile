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

load "ruby-dbus.gemspec"

Rake::GemPackageTask.new(GEMSPEC) do |pkg|
  # no other formats needed
end

Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc/rdoc'
  rd.rdoc_files.include("README", "lib/**/*.rb")
#  rd.options << "--diagram"
#  rd.options << "--all"
end

desc "Render the tutorial in HTML"
task :tutorial => "doc/tutorial/index.html"
file "doc/tutorial/index.html" => "doc/tutorial/index.markdown" do |t|
  sh "markdown #{t.prerequisites[0]} > #{t.name}"
end
