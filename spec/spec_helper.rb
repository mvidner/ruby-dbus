# frozen_string_literal: true

require_relative "coverage_helper"

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

# http://betterspecs.org/#expect
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
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
  exec = "#{TOPDIR}/spec/mock-service/spaghetti-monster.rb"

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

  # This would kill also other instances,
  # namely on the bus set up by test_env.
  ## system "pkill -f #{exec}"
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
