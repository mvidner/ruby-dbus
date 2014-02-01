#!/usr/bin/env ruby
# Test the binding of dbus concepts to ruby concepts
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class AsyncTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @obj = @svc.object "/org/ruby/MyInstance"
    @obj.introspect
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  # https://github.com/mvidner/ruby-dbus/issues/13
  def test_async_call_to_default_interface
    loop = DBus::Main.new
    loop << @bus

    immediate_answer = @obj.the_answer do |msg, retval|
      assert_equal 42, retval
      loop.quit
    end

    assert_nil immediate_answer

    # wait for the async reply
    loop.run
  end

  def test_async_call_to_explicit_interface
    loop = DBus::Main.new
    loop << @bus

    ifc = @obj["org.ruby.AnotherInterface"]
    immediate_answer = ifc.Reverse("abcd") do |msg, retval|
      assert_equal "dcba", retval
      loop.quit
    end

    assert_nil immediate_answer

    # wait for the async reply
    loop.run
  end

end
