if ENV["COVERAGE"]
  coverage = ENV["COVERAGE"] == "true"
else
  # heuristics: enable for interactive builds (but not in OBS) or in Travis
  coverage = !!ENV["DISPLAY"] || ENV["TRAVIS"]
end

if coverage
  require "simplecov"
  SimpleCov.root File.expand_path("../..", __FILE__)
  # use coveralls for on-line code coverage reporting at Travis CI
  if ENV["TRAVIS"]
    require "coveralls"

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
      SimpleCov::Formatter::HTMLFormatter,
      Coveralls::SimpleCov::Formatter
    ]
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
