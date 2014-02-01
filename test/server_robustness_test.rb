#!/usr/bin/env ruby
# Test that a server survives various error cases
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class ServerRobustnessTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
  end

  # https://trac.luon.net/ruby-dbus/ticket/31
  # the server should not crash
  def test_no_such_path_with_introspection
    obj = @svc.object "/org/ruby/NotMyInstance"
    obj.introspect
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end

  def test_no_such_path_without_introspection
    obj = @svc.object "/org/ruby/NotMyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.SampleInterface")
    ifc.define_method("the_answer", "out n:i")
    ifc.the_answer
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end

  def test_a_method_that_raises
    obj = @svc.object "/org/ruby/MyInstance"
    obj.introspect
    obj.default_iface = "org.ruby.SampleInterface"
    obj.will_raise
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end

  def test_a_method_that_raises_name_error
    obj = @svc.object "/org/ruby/MyInstance"
    obj.introspect
    obj.default_iface = "org.ruby.SampleInterface"
    obj.will_raise_name_error
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end

  # https://trac.luon.net/ruby-dbus/ticket/31#comment:3
  def test_no_such_method_without_introspection
    obj = @svc.object "/org/ruby/MyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.SampleInterface")
    ifc.define_method("not_the_answer", "out n:i")
    ifc.not_the_answer
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end

  def test_no_such_interface_without_introspection
    obj = @svc.object "/org/ruby/MyInstance"
    ifc = DBus::ProxyObjectInterface.new(obj, "org.ruby.NoSuchInterface")
    ifc.define_method("the_answer", "out n:i")
    ifc.the_answer
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_no_match(/timeout/, e.to_s)
  end
end
