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

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

if Object.const_defined? "RSpec"
  # http://betterspecs.org/#expect
  RSpec.configure do |config|
    config.expect_with :rspec do |c|
      c.syntax = :expect
    end
  end
end

require "tempfile"
require "timeout"

TOPDIR = File.expand_path("..", __dir__)

# path of config file for a private bus
def config_file_path
  "#{TOPDIR}/spec/tools/dbus-limited-session.conf"
end

# set ENV[variable] to value and restore it after block is done
def with_env(variable, value, &block)
  old_value = ENV[variable]
  ENV[variable] = value
  block.call
  ENV[variable] = old_value
end

# Set up a private session bus and run *block* with that.
def with_private_bus(&block)
  address_file = Tempfile.new("dbus-address")
  pid_file     = Tempfile.new("dbus-pid")
  output_file  = Tempfile.new("dbus-output") # just in case

  temp_dir = Dir.mktmpdir
  with_env("XDG_DATA_DIRS", temp_dir) do
    cmd = "dbus-daemon --nofork --config-file=#{config_file_path} " \
          "--print-address=3 3>#{address_file.path} " \
          "--print-pid=4 4>#{pid_file.path} " \
          ">#{output_file.path} 2>&1 &"
    system cmd

    # wait until dbus-daemon writes the info
    Timeout.timeout(10) do
      until File.size?(address_file) && File.size?(pid_file)
        sleep 0.1
      end
    end

    address = address_file.read.chomp
    pid = pid_file.read.chomp.to_i

    with_env("DBUS_SESSION_BUS_ADDRESS", address) do
      block.call
    end

    Process.kill("TERM", pid)
  end
  FileUtils.rm_rf temp_dir
end

def with_service_by_activation(&block)
  name = "org.ruby.service"
  exec = "#{TOPDIR}/spec/service_newapi.rb"

  service_dir = "#{ENV["XDG_DATA_DIRS"]}/dbus-1/services"
  FileUtils.mkdir_p service_dir
  # file name actually does not need to match the service name
  File.open("#{service_dir}/#{name}.service", "w") do |f|
    s = <<-TEXT.gsub(/^\s*/, "")
      [D-BUS Service]
      Name=#{name}
      Exec=#{exec}
    TEXT
    f.write(s)
  end

  block.call

  system "pkill -f #{exec}"
end

# Make a binary string from readable YAML pieces; see data/marshall.yaml
def buffer_from_yaml(parts)
  strings = parts.flatten.map do |part|
    if part.is_a? Integer
      part.chr
    else
      part
    end
  end
  strings.join.force_encoding(Encoding::BINARY)
end
