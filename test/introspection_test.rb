#!/usr/bin/env ruby
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class IntrospectionTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::ASessionBus.new
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  def test_wrong_number_of_arguments
    assert_raise(ArgumentError) { @obj.test_variant "too","many","args" }
    assert_raise(ArgumentError) { @obj.test_variant } # not enough
  end

  def test_shortcut_methods
    @obj.default_iface = nil
    assert_equal(["varargs"], @obj.bounce_variant("varargs"))
    # test for a duplicated method name
    assert_raise(NoMethodError) { @obj.the_answer }
    # ensure istance methods of ProxyObject aren't overwritten by remote
    # methods
    assert_nothing_raised { @obj.interfaces }

    @obj.default_iface = "org.ruby.SampleInterface"
    assert_equal [42], @obj.the_answer
  end
end
