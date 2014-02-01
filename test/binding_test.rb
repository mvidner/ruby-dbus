#!/usr/bin/env ruby
# Test the binding of dbus concepts to ruby concepts
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class BindingTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @base = @svc.object "/org/ruby/MyInstance"
    @base.introspect
    @base.default_iface = "org.ruby.SampleInterface"
  end

  # https://trac.luon.net/ruby-dbus/ticket/36#comment:3
  def test_class_inheritance
    derived = @svc.object "/org/ruby/MyDerivedInstance"
    derived.introspect

    # it should inherit from the parent
    assert_not_nil derived["org.ruby.SampleInterface"]
  end

  # https://trac.luon.net/ruby-dbus/ticket/36
  # Interfaces and methods/signals appeared on all classes
  def test_separation_of_classes
    test2 = @svc.object "/org/ruby/MyInstance2"
    test2.introspect

    # it should have its own interface
    assert_not_nil test2["org.ruby.Test2"]
    # but not an interface of the Test class
    assert_nil test2["org.ruby.SampleInterface"]

    # and the parent should not get polluted by the child
    assert_nil @base["org.ruby.Test2"]
  end

  def test_translating_errors_into_exceptions
    # this is a generic call that will reply with the specified error
    @base.Error "org.example.Fail", "as you wish"
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_equal "org.example.Fail", e.name
    assert_equal "as you wish", e.message
  end

  def test_generic_dbus_error
    # this is a generic call that will reply with the specified error
    @base.will_raise_error_failed
    assert false, "should have raised"
  rescue DBus::Error => e
    assert_equal "org.freedesktop.DBus.Error.Failed", e.name
    assert_equal "failed as designed", e.message
  end
  
  def test_dynamic_interface_definition
    # interfaces can be defined dynamicaly
    derived = DBus::Object.new "/org/ruby/MyDerivedInstance"
    
    #define a new interface
    derived.singleton_class.instance_eval do
      dbus_interface "org.ruby.DynamicInterface" do
        dbus_method :hello2, "in name:s, in name2:s" do |name, name2|
          puts "hello(#{name}, #{name2})"
        end
      end
    end
    
    # the object should have the new iface
    ifaces = derived.intfs
    assert ifaces and ifaces.include?("org.ruby.DynamicInterface")
  end
    
end
