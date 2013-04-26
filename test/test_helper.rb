# Coverage: if available, but not in Travis
if RUBY_VERSION >= "1.9" && ! ENV["CI"]
  require 'simplecov'
  SimpleCov.start
end
$:.unshift File.expand_path("../../lib", __FILE__)
