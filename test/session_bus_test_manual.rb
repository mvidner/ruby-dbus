#!/usr/bin/env ruby
require "test/unit"
require "dbus"

class SessionBusAddressTest < Test::Unit::TestCase
  def setup
    # test getting the session bus address even if unset in ENV (Issue#4)
    ENV.delete "DBUS_SESSION_BUS_ADDRESS"
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.freedesktop.DBus")
  end

  def test_connection
    assert @svc.exists?
  end
end
