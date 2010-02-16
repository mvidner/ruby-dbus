#!/usr/bin/env ruby
# Test that a server survives various error cases
require "test/unit"
require "dbus"

class Foo < DBus::Object
  dbus_interface "org.ruby.ServerTest" do
    dbus_signal :signal_without_arguments
    dbus_signal :signal_with_argument, "epsilon:d"
  end

  dbus_signal :signal_without_interface
rescue DBus::Object::UndefinedInterface => e
  # raised by the preceding signal declaration
end

class ServerTest < Test::Unit::TestCase
  def setup
    @bus = DBus::SessionBus.instance
    @svc = @bus.request_service "org.ruby.server-test"
  end

  def teardown
    @bus.proxy.ReleaseName "org.ruby.server-test"
  end

  def test_unexporting_an_object
    obj = Foo.new "/org/ruby/Foo"
    @svc.export obj
    assert @svc.unexport(obj)
  end

  def test_unexporting_an_object_not_exported
    obj = Foo.new "/org/ruby/Foo"
    assert !@svc.unexport(obj)
  end

  def test_emiting_signals
    obj = Foo.new "/org/ruby/Foo"
    @svc.export obj
    obj.signal_without_arguments    
    obj.signal_with_argument(-0.1)
  end
end
