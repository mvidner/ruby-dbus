require_relative "test_helper"
SimpleCov.command_name "Specs" if Object.const_defined? "SimpleCov"

# http://betterspecs.org/#expect
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
