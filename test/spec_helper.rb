if ENV["COVERAGE"]
  coverage = ENV["COVERAGE"] == "true"
else
  # heuristics: enable for interactive builds (but not in OBS) or in Travis
  coverage = !!ENV["DISPLAY"] || ENV["TRAVIS"]
end

if coverage
  require "simplecov"
  SimpleCov.root File.expand_path("../..", __FILE__)

  # do not cover specs
  SimpleCov.add_filter "_spec.rb"
  # do not cover the activesupport helpers
  SimpleCov.add_filter "/core_ext/"

  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"
  end
  SimpleCov.start
end

$:.unshift File.expand_path("../../lib", __FILE__)

if Object.const_defined? "RSpec"
  # http://betterspecs.org/#expect
  RSpec.configure do |config|
    config.expect_with :rspec do |c|
      c.syntax = :expect
    end
  end
end
