#! /usr/bin/env ruby
# frozen_string_literal: true

require "rake"
require "fileutils"
require "tmpdir"
require "rspec/core/rake_task"
begin
  require "rubocop/rake_task"
rescue LoadError
  nil
end
begin
  require "yard"
rescue LoadError
  nil
end

require "packaging"

Packaging.configuration do |conf|
  conf.obs_project = "devel:languages:ruby:extensions"
  conf.obs_target = "openSUSE_Tumbleweed"
  conf.package_name = "rubygem-ruby-dbus"
  conf.obs_sr_project = "openSUSE:Factory"
  conf.skip_license_check << %r{^[^/]*$}
  conf.skip_license_check << %r{^(doc|examples|spec)/.*}
  # "Ruby on Rails is released under the MIT License."
  # but the files are missing copyright headers
  conf.skip_license_check << %r{^lib/dbus/core_ext/}
end

desc "Default: run specs in the proper environment"
task default: [:spec, :rubocop]
task test: :spec

RSpec::Core::RakeTask.new("bare:spec")

["spec"].each do |tname|
  desc "Run bare:#{tname} in the proper environment"
  task tname do |_t|
    cd "spec/tools" do
      sh "./test_env rake bare:#{tname}"
    end
  end
end

# remove tarball implementation and create gem for this gemfile
Rake::Task[:tarball].clear

desc "Build a package from a clone of the local Git repo"
task :tarball do |_t|
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

if Object.const_defined? :RuboCop
  RuboCop::RakeTask.new
else
  desc "Run RuboCop (dummy)"
  task :rubocop do
    warn "RuboCop not installed"
  end
end

YARD::Rake::YardocTask.new if Object.const_defined? :YARD
