#!/usr/bin/env rspec
# frozen_string_literal: true

# Test that a server survives various error cases
require_relative "spec_helper"
require "dbus"

describe "ServerRobustnessTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
  end

  # https://trac.luon.net/ruby-dbus/ticket/31
  # the server should not crash
  it "tests no such path with introspection" do
    obj = @svc.object "/org/ruby/NotMyInstance"
    expect { obj.introspect }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end

  it "tests no such path without introspection" do
    obj = @svc.object "/org/ruby/NotMyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.SampleInterface")
    ifc.define_method("the_answer", "out n:i")
    expect { ifc.the_answer }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end

  context "an existing path without an object" do
    let(:obj) { @svc.object "/org" }

    it "errors without a timeout" do
      ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.SampleInterface")
      ifc.define_method("the_answer", "out n:i")
      expect { ifc.the_answer }.to raise_error(DBus::Error) do |e|
        expect(e.message).to_not match(/timeout/)
      end
    end
  end

  it "tests a method that raises" do
    obj = @svc.object "/org/ruby/MyInstance"
    obj.default_iface = "org.ruby.SampleInterface"
    expect { obj.will_raise }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end

  it "tests a method that raises name error" do
    obj = @svc.object "/org/ruby/MyInstance"
    obj.default_iface = "org.ruby.SampleInterface"
    expect { obj.will_raise_name_error }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end

  # https://trac.luon.net/ruby-dbus/ticket/31#comment:3
  it "tests no such method without introspection" do
    obj = @svc.object "/org/ruby/MyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.SampleInterface")
    ifc.define_method("not_the_answer", "out n:i")
    expect { ifc.not_the_answer }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end

  it "tests no such interface without introspection" do
    obj = @svc.object "/org/ruby/MyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.NoSuchInterface")
    ifc.define_method("the_answer", "out n:i")
    expect { ifc.the_answer }.to raise_error(DBus::Error) do |e|
      expect(e.message).to_not match(/timeout/)
    end
  end
end
