#!/usr/bin/env ruby
# should report it missing on org.ruby.SampleInterface
# (on object...) instead of on DBus::Proxy::ObjectInterface
require "test/unit"
require "dbus"

class ErrMsgTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::ASessionBus.new
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
      assert_match(/DBus interface.*#{@obj.default_iface}/, e.to_s)
    end
  end

  def test_report_short_struct
    begin
      @obj.test_variant ["(ss)", ["too few"] ]
    rescue DBus::TypeException => e
      assert_match(/1 elements but type info for 2/, e.to_s)
    end
  end

  def test_report_long_struct
    begin
      @obj.test_variant ["(ss)", ["a", "b", "too many"] ]
    rescue DBus::TypeException => e
      assert_match(/3 elements but type info for 2/, e.to_s)
    end
  end

  def test_report_nil
    nils = [
            ["(s)", [nil] ],    # would get disconnected
            ["i", nil ],
            ["a{ss}", {"foo" => nil} ],
           ]
    nils.each do |has_nil|
      begin
        @obj.test_variant has_nil
      rescue DBus::TypeException => e
        # TODO want backtrace from the perspective of the caller:
        # rescue/reraise in send_sync?
        assert_match(/Cannot send nil/, e.to_s)
      end
    end
  end
end
