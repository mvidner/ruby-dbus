#! /usr/bin/env ruby
require 'rake'
require 'fileutils'
include FileUtils
require 'tmpdir'
require 'rspec/core/rake_task'

require "packaging"

Packaging.configuration do |conf|
  conf.obs_project = "devel:languages:ruby:extensions"
  conf.package_name = "rubygem-ruby-dbus"
  conf.obs_sr_project = "openSUSE:Factory"
  conf.skip_license_check << /^[^\/]*$/
  conf.skip_license_check << /^(doc|examples|spec)\/.*/
  # "Ruby on Rails is released under the MIT License."
  # but the files are missing copyright headers
  conf.skip_license_check << /^lib\/dbus\/core_ext\//
end

desc 'Default: run specs in the proper environment'
task :default => :spec
task :test => :spec

RSpec::Core::RakeTask.new("bare:spec")

%w(spec).each do |tname|
  desc "Run bare:#{tname} in the proper environment"
  task tname do |t|
    cd "spec/tools" do
      sh "./test_env rake bare:#{tname}"
    end
  end
end

if ENV["TRAVIS"]
  require "coveralls/rake/task"
  Coveralls::RakeTask.new
  task :default => "coveralls:push"
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
    sh "rm -f package/*.gem"
    cp Dir.glob("#{temp}/*.gem"), "package"
  end
end

namespace :doc do
  desc "Extract code examples from doc/Reference.md to examples/doc"
  task :examples do
    cd "examples/doc" do
      sh "./_extract_examples ../../doc/Reference.md"
    end
  end
end
