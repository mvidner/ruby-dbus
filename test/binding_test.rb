#!/usr/bin/env ruby
# Test the binding of dbus concepts to ruby concepts
require "test/unit"
require "dbus"

class BindingTest < Test::Unit::TestCase
  def setup
    @bus = DBus::SessionBus.instance
    @svc = @bus.service("org.ruby.service")
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

    base = @svc.object "/org/ruby/MyInstance"
    base.introspect
    # and the parent should not get polluted by the child
    assert_nil base["org.ruby.Test2"]
  end
end
