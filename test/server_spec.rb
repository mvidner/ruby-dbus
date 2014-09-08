#!/usr/bin/env rspec
# Test that a server survives various error cases
require_relative "spec_helper"
require "dbus"

class Foo < DBus::Object
  dbus_interface "org.ruby.ServerTest" do
    dbus_signal :signal_without_arguments
    dbus_signal :signal_with_argument, "epsilon:d"
  end

  dbus_signal :signal_without_interface
rescue DBus::Object::UndefinedInterface
  # raised by the preceding signal declaration
end

class Bar < DBus::Object
  dbus_interface "org.ruby.ServerTest" do
    # a valid Ruby symbol but an invalid DBus name; Ticket#38
    dbus_signal :signal_with_a_bang!
  end
rescue DBus::InvalidMethodName
  # raised by the preceding signal declaration
end

describe "ServerTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.request_service "org.ruby.server-test"
  end

  after(:each) do
    @bus.proxy.ReleaseName "org.ruby.server-test"
  end

  it "tests unexporting an object" do
    obj = Foo.new "/org/ruby/Foo"
    @svc.export obj
    expect(@svc.unexport(obj)).to be true
  end

  it "tests unexporting an object not exported" do
    obj = Foo.new "/org/ruby/Foo"
    expect(@svc.unexport(obj)).to be false
  end

  it "tests emiting signals" do
    obj = Foo.new "/org/ruby/Foo"
    @svc.export obj
    obj.signal_without_arguments
    obj.signal_with_argument(-0.1)
  end
end
