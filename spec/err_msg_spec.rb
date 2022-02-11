#!/usr/bin/env rspec
# frozen_string_literal: true

# should report it missing on org.ruby.SampleInterface
# (on object...) instead of on DBus::Proxy::ObjectInterface
require_relative "spec_helper"
require "dbus"

describe "ErrMsgTest" do
  before(:each) do
    session_bus = DBus::ASessionBus.new
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  it "tests report dbus interface" do
    # a specific exception...
    # mentioning DBus and the interface
    expect { @obj.NoSuchMethod }
      .to raise_error(NameError, /DBus interface.*#{@obj.default_iface}/)
  end

  it "tests report short struct" do
    expect { @obj.test_variant ["(ss)", ["too few"]] }
      .to raise_error(DBus::TypeException, /1 elements but type info for 2/)
  end

  it "tests report long struct" do
    expect { @obj.test_variant ["(ss)", ["a", "b", "too many"]] }
      .to raise_error(DBus::TypeException, /3 elements but type info for 2/)
  end

  it "tests report nil" do
    nils = [
      ["(s)", [nil]], # would get disconnected
      ["i", nil],
      ["a{ss}", { "foo" => nil }]
    ]
    nils.each do |has_nil|
      # TODO: want backtrace from the perspective of the caller:
      # rescue/reraise in send_sync?
      expect { @obj.test_variant has_nil }
        .to raise_error(DBus::TypeException, /Cannot send nil/)
    end
  end
end
