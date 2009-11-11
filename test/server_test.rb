#!/usr/bin/env ruby
# Test that a server survives various error cases
require "test/unit"
require "dbus"

class Foo < DBus::Object
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
end
