#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

require "tempfile"
require "timeout"

TOPDIR = File.expand_path("../..", __FILE__)

def config_file_path
  "#{TOPDIR}/test/tools/dbus-limited-session.conf"
end

def setup_private_bus
  $temp_dir = Dir.mktmpdir
  ENV["XDG_DATA_DIRS"] = $temp_dir

  address_file = Tempfile.new("dbus-address")
  pid_file     = Tempfile.new("dbus-pid")

  cmd = "dbus-daemon --nofork --config-file=#{config_file_path} --print-address=3 3>#{address_file.path} --print-pid=4 4>#{pid_file.path} &"
  system cmd

  # wait until dbus-daemon writes the info
  Timeout.timeout(10) do
    until File.size?(address_file) and File.size?(pid_file) do
      sleep 0.1
    end
  end

  address = address_file.read.chomp
  $pid = pid_file.read.chomp.to_i

  ENV["DBUS_SESSION_BUS_ADDRESS"] = address
end

def teardown_private_bus
  Process.kill("TERM", $pid)
  FileUtils.rm_rf $temp_dir
end

def setup_service_by_activation
  name = "org.ruby.service"
  exec = "#{TOPDIR}/test/service_newapi.rb"
  $exec = exec

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
end

def teardown_service
  system "pkill -f #{$exec}"
end

describe DBus::Service do
  context "when a private bus is set up" do
    before(:all) do
      setup_private_bus
      setup_service_by_activation
    end
    after(:all) do
      teardown_service
      teardown_private_bus
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
