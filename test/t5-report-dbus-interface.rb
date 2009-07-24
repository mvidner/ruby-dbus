#!/usr/bin/ruby
# should report it missing on org.ruby.SampleInterface
# (on object...) instead of on DBus::Proxy::ObjectInterface
require "test/unit"
require "dbus"

class ErrMsgTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::SessionBus.instance
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  def test_report_dbus_interface
    begin
      @obj.NoSuchMethod
    # a specific exception...
    rescue NameError => e
      # mentioning DBus and the interface
      assert_match /DBus interface.*#{@obj.default_iface}/, e.to_s
    end
  end
end

