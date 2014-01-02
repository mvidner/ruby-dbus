#! /usr/bin/env ruby
require 'rake'
require 'fileutils'
include FileUtils
require 'tmpdir'
require 'rake/testtask'

require "packaging"

Packaging.configuration do |conf|
  conf.obs_project = "devel:languages:ruby:extensions"
  conf.package_name = "rubygem-ruby-dbus"
  conf.obs_sr_project = "openSUSE:Factory"
  conf.skip_license_check << /^[^\/]*$/
  conf.skip_license_check << /^(doc|examples|test)\/.*/
end

desc 'Default: run tests in the proper environment'
task :default => :test

def common_test_task(t)
    t.libs << "lib"
    t.test_files = FileList['test/*_test.rb']
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
    cd "test/tools" do
      sh "./test_env rake bare:#{tname}"
    end
  end
end

#remove tarball implementation and create gem for this gemfile
Rake::Task[:tarball].clear

desc "Build a package from a clone of the local Git repo"
task :tarball do |t|
  Dir.mktmpdir do |temp|
    sh "git clone . #{temp}"
    cd temp do
      sh "gem build ruby-dbus.gemspec"
    end
    cp Dir.glob("#{temp}/*.gem"), "package"
  end
end
