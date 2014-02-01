#!/usr/bin/env ruby
# Test the bus class
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class BusTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @svc.object("/").introspect
  end

  def test_introspection_not_leaking
    # peek inside the object to see if a cleanup step worked or not
    some_hash = @bus.instance_eval { @method_call_replies || Hash.new }
    assert_equal 0, some_hash.size, "there are leftover method handlers"
  end
end
