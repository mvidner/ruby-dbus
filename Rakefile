#! /usr/bin/env ruby
require 'rake'
require 'fileutils'
include FileUtils
require 'tmpdir'
require 'rake/rdoctask'
require 'rake/testtask'

desc 'Default: run tests in the proper environment'
task :default => :test

def common_test_task(t)
    t.libs << "lib"
    t.test_files = FileList['test/*_test.rb', 'test/t[0-9]*.rb']
    t.verbose = true
end
Rake::TestTask.new("bare:test") {|t| common_test_task t }

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new("bare:rcov") {|t| common_test_task t }
rescue LoadError
  # no rcov, never mind
end

%w(test rcov).each do |tname|
  desc "Run bare:#{tname} in the proper environment"
  task tname do |t|
    cd "test" do
      sh "./test_env rake bare:#{tname}"
    end
  end
end

desc "Build the gem file"
task :package do
  sh "gem build ruby-dbus.gemspec"
end

desc "Build a package from a clone of the local Git repo"
task :package_git do |t|
  Dir.mktmpdir do |temp|
    sh "git clone . #{temp}"
    cd temp do
      sh "rake package"
    end
    cp Dir.glob("#{temp}/*.gem"), "."
  end
end

Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc/rdoc'
  rd.rdoc_files.include("README", "lib/**/*.rb")
#  rd.options << "--diagram"
#  rd.options << "--all"
end
