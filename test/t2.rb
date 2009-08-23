#!/usr/bin/env ruby
require "test/unit"
require "dbus"

class ValueTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::SessionBus.instance
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  def test_passing_an_array_through_a_variant
    @obj.test_variant(["as", ["coucou", "kuku"]])
  end

  def test_marshalling_an_array_of_variants
    # https://trac.luon.net/ruby-dbus/ticket/30
    choices = []
    choices << ['s', 'Plan A']
    choices << ['s', 'Plan B']
    @obj.default_iface = "org.ruby.Ticket30"
    p @obj.Sybilla(choices)
  end
end
