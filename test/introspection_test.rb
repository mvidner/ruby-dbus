#!/usr/bin/env ruby
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
end
