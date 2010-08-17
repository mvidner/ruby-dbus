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
end
