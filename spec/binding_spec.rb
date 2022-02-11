#!/usr/bin/env rspec
# frozen_string_literal: true

# Test the binding of dbus concepts to ruby concepts
require_relative "spec_helper"

require "dbus"

describe "BindingTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @base = @svc.object "/org/ruby/MyInstance"
    @base.default_iface = "org.ruby.SampleInterface"
  end

  # https://trac.luon.net/ruby-dbus/ticket/36#comment:3
  it "tests class inheritance" do
    derived = @svc.object "/org/ruby/MyDerivedInstance"

    # it should inherit from the parent
    expect(derived["org.ruby.SampleInterface"]).not_to be_nil
  end

  # https://trac.luon.net/ruby-dbus/ticket/36
  # Interfaces and methods/signals appeared on all classes
  it "tests separation of classes" do
    test2 = @svc.object "/org/ruby/MyInstance2"

    # it should have its own interface
    expect(test2["org.ruby.Test2"]).not_to be_nil
    # but not an interface of the Test class
    expect { test2["org.ruby.SampleInterface"] }.to raise_error(DBus::Error) do |e|
      expect(e.message).to match(/no such interface/)
    end

    # and the parent should not get polluted by the child
    expect { @base["org.ruby.Test2"] }.to raise_error(DBus::Error) do |e|
      expect(e.message).to match(/no such interface/)
    end
  end

  it "tests translating errors into exceptions" do
    # this is a generic call that will reply with the specified error
    expect { @base.Error "org.example.Fail", "as you wish" }.to raise_error(DBus::Error) do |e|
      expect(e.name).to eq("org.example.Fail")
      expect(e.message).to match(/as you wish/)
    end
  end

  it "tests generic dbus error" do
    # this is a generic call that will reply with the specified error
    expect { @base.will_raise_error_failed }.to raise_error(DBus::Error) do |e|
      expect(e.name).to eq("org.freedesktop.DBus.Error.Failed")
      expect(e.message).to match(/failed as designed/)
    end
  end

  it "tests dynamic interface definition" do
    # interfaces can be defined dynamicaly
    derived = DBus::Object.new "/org/ruby/MyDerivedInstance"

    # define a new interface
    derived.singleton_class.instance_eval do
      dbus_interface "org.ruby.DynamicInterface" do
        dbus_method :hello2, "in name:s, in name2:s" do |name, name2|
          puts "hello(#{name}, #{name2})"
        end
      end
    end

    # the object should have the new iface
    ifaces = derived.intfs
    expect(ifaces).to include "org.ruby.DynamicInterface"
  end
end
