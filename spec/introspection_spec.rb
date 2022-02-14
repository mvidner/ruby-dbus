#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe "IntrospectionTest" do
  before(:each) do
    session_bus = DBus::ASessionBus.new
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  it "tests wrong number of arguments" do
    expect { @obj.test_variant "too", "many", "args" }.to raise_error(ArgumentError)
    # not enough
    expect { @obj.test_variant }.to raise_error(ArgumentError)
  end

  it "tests shortcut methods" do
    @obj.default_iface = nil
    expect(@obj.bounce_variant("varargs")).to eq(["varargs"])
    # test for a duplicated method name
    expect { @obj.the_answer }.to raise_error(NoMethodError)
    # ensure istance methods of ProxyObject aren't overwritten by remote
    # methods
    expect { @obj.interfaces }.not_to raise_error

    @obj.default_iface = "org.ruby.SampleInterface"
    expect(@obj.the_answer).to eq([42])
  end
end
