if ENV["COVERAGE"]
  coverage = ENV["COVERAGE"] == "true"
else
  # heuristics: enable for interactive builds but not in Travis or OBS
  coverage = !!ENV["DISPLAY"]
end

if coverage && RUBY_VERSION >= "1.9" # SimpleCov does not work with 1.8
  require 'simplecov'
  SimpleCov.root File.expand_path("../..", __FILE__)
  SimpleCov.start
end

$:.unshift File.expand_path("../../lib", __FILE__)
