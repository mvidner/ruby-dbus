#!/usr/bin/env rspec
# frozen_string_literal: true

# Test the binding of dbus concepts to ruby concepts
require_relative "spec_helper"
require "dbus"

describe "AsyncTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @obj = @svc.object "/org/ruby/MyInstance"
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  # https://github.com/mvidner/ruby-dbus/issues/13
  it "tests async_call_to_default_interface" do
    loop = DBus::Main.new
    loop << @bus

    immediate_answer = @obj.the_answer do |_msg, retval|
      expect(retval).to eq(42)
      loop.quit
    end

    expect(immediate_answer).to be_nil

    # wait for the async reply
    loop.run
  end

  it "tests async_call_to_explicit_interface" do
    loop = DBus::Main.new
    loop << @bus

    ifc = @obj["org.ruby.AnotherInterface"]
    immediate_answer = ifc.Reverse("abcd") do |_msg, retval|
      expect(retval).to eq("dcba")
      loop.quit
    end

    expect(immediate_answer).to be_nil

    # wait for the async reply
    loop.run
  end
end
