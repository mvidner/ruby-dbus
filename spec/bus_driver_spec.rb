#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

require "tempfile"
require "timeout"

TOPDIR = File.expand_path("../..", __FILE__)

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

def with_private_bus(&block)
  address_file = Tempfile.new("dbus-address")
  pid_file     = Tempfile.new("dbus-pid")

  $temp_dir = Dir.mktmpdir
  with_env("XDG_DATA_DIRS", $temp_dir) do
    cmd = "dbus-daemon --nofork --config-file=#{config_file_path} --print-address=3 3>#{address_file.path} --print-pid=4 4>#{pid_file.path} &"
    system cmd
  end

  # wait until dbus-daemon writes the info
  Timeout.timeout(10) do
    until File.size?(address_file) and File.size?(pid_file) do
      sleep 0.1
    end
  end

  address = address_file.read.chomp
  $pid = pid_file.read.chomp.to_i

  with_env("DBUS_SESSION_BUS_ADDRESS", address) do
    block.call
  end

  Process.kill("TERM", $pid)
  FileUtils.rm_rf $temp_dir
end

def with_service_by_activation(&block)
  name = "org.ruby.service"
  exec = "#{TOPDIR}/test/service_newapi.rb"

  service_dir = "#{$temp_dir}/dbus-1/services"
  FileUtils.mkdir_p service_dir
  # file name actually does not need to match the service name
  File.open("#{service_dir}/#{name}.service", "w") do |f|
    s = <<EOS
[D-BUS Service]
Name=#{name}
Exec=#{exec}
EOS
    f.write(s)
  end

  block.call

  system "pkill -f #{exec}"
end

describe DBus::Service do
  context "when a private bus is set up" do
    around(:each) do |example|
      with_private_bus do
        with_service_by_activation(&example)
      end
    end

    let(:bus) { DBus::ASessionBus.new }

    describe "#exists?" do
      it "is true for an existing service" do
        svc = bus.service("org.ruby.service")
        svc.object("/").introspect # must activate the service first :-/
        expect(svc.exists?).to be_true
      end

      it "is false for a nonexisting service" do
        svc = bus.service("org.ruby.nosuchservice")
        expect(svc.exists?).to be_false
      end
    end
  end
end
