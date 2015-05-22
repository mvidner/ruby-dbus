#!/usr/bin/env rspec
# Test the binding of dbus concepts to ruby concepts
require_relative "spec_helper"

require "dbus"

describe "TimeoutTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @base = @svc.object "/org/ruby/MyInstance"
    @base.introspect
    @base.default_iface = "org.ruby.SampleInterface"
  end

  it "tests default (infinite) timeout" do
    expect { @base.Sleep(1.0) }.to_not raise_error
  end

  it "tests a sufficient timeout" do
    @bus.timeout = 10.0 # seconds
    expect { @base.Sleep(1.0) }.to_not raise_error
  end

  it "tests an insufficient timeout" do
    @bus.timeout = 0.5 # seconds
    expect { @base.Sleep(1.0) }.to raise_error(DBus::Error)
  end

end
