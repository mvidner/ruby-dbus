#!/usr/bin/env ruby
# Test the methods of the bus driver
require "test/unit"
require "dbus"

def d(msg)
  puts msg if $DEBUG
end

class BusDriverTest < Test::Unit::TestCase
  def setup
    @bus = DBus::SessionBus.instance
    @svc = @bus.service("org.ruby.service")
  end

  def test_exists
    assert @svc.exists?
    nonsvc = @bus.service "org.ruby.nosuchservice"
    assert ! nonsvc.exists?
  end
end
