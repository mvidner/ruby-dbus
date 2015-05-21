#!/usr/bin/env rspec
# Test the binding of dbus concepts to ruby concepts
require_relative "spec_helper"

require "dbus"

describe "TimeoutTest" do
  around(:each) do |example|
    with_private_bus do
      with_service_by_activation(&example)
    end
  end

  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @base = @svc.object "/org/ruby/MyInstance"
    @base.introspect
    @base.default_iface = "org.ruby.SampleInterface"
  end

  it "tests default (infinite) timeout" do
    # WTF, sleep works, via foo.method(:sleep).call(1.0)
    #  even 1.method(:sleep).call(1.0) works.
    expect { @base.sleep(1.0) }.to_not raise_error
  end

  it "tests a sufficient timeout" do
    @bus.timeout = 10.0 # seconds
    expect { @base.sleep(1.0) }.to_not raise_error
  end

  it "tests an insufficient timeout" do
    @bus.timeout = 0.5 # seconds
    expect { @base.sleep(1.0) }.to raise_error # FIXME a specific exception? which?
# "org.freedesktop.DBus.Error.NoReply"

#"org.freedesktop.DBus.Error.Timeout"
#"org.freedesktop.DBus.Error.TimedOut"
  end

end
