#!/usr/bin/env ruby
# Test the methods of the bus driver
require "test/unit"
require "dbus"

class BusDriverTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @svc.object("/").introspect
  end

  def test_exists
    assert @svc.exists?, "could not find the service"
    nonsvc = @bus.service "org.ruby.nosuchservice"
    assert ! nonsvc.exists?, "found a service that should not exist"
  end
end
