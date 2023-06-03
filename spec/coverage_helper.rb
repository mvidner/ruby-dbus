# frozen_string_literal: true

coverage = if ENV["COVERAGE"]
             ENV["COVERAGE"] == "true"
           else
             # heuristics: enable for interactive builds (but not in OBS)
             ENV["DISPLAY"]
           end

if coverage
  require "simplecov"
  SimpleCov.root File.expand_path("..", __dir__)

  # do not cover specs
  SimpleCov.add_filter "_spec.rb"
  # do not cover the activesupport helpers
  SimpleCov.add_filter "/core_ext/"
  # measure all if/else branches on a line
  SimpleCov.enable_coverage :branch

  SimpleCov.start

  # additionally use the LCOV format for on-line code coverage reporting at CI
  if ENV["COVERAGE_LCOV"] == "true"
    require "simplecov-lcov"

    SimpleCov::Formatter::LcovFormatter.config do |c|
      c.report_with_single_file = true
      # this is the default Coveralls GitHub Action location
      # https://github.com/marketplace/actions/coveralls-github-action
      c.single_report_path = "coverage/lcov.info"
    end

    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::LcovFormatter
    ]
  end
end
