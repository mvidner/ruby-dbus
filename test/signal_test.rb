#!/usr/bin/env ruby
# Test the signal handlers
require File.expand_path("../test_helper", __FILE__)
require "test/unit"
require "dbus"

class SignalHandlerTest < Test::Unit::TestCase
  def setup
    @session_bus = DBus::ASessionBus.new
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.Loop"
    @intf = @obj["org.ruby.Loop"]

    @loop = DBus::Main.new
    @loop << @session_bus
  end

  # testing for commit 017c83 (kkaempf)
  def test_overriding_a_handler
    DBus.logger.debug "Inside test_overriding_a_handler"
    counter = 0

    @obj.on_signal "LongTaskEnd" do
      DBus.logger.debug "+10"
      counter += 10
    end
    @obj.on_signal "LongTaskEnd" do
      DBus.logger.debug "+1"
      counter += 1
    end

    DBus.logger.debug "will begin"
    @obj.LongTaskBegin 3

    quitter = Thread.new do
      DBus.logger.debug "sleep before quit"
      # FIXME if we sleep for too long
      # the socket will be drained and we deadlock in a select.
      # It could be worked around by sending ourselves a Unix signal
      # (with a dummy handler) to interrupt the select
      sleep 1
      DBus.logger.debug "will quit"
      @loop.quit
    end
    @loop.run
    quitter.join

    assert_equal 1, counter
  end

  def test_on_signal_overload
    DBus.logger.debug "Inside test_on_signal_overload"
    counter = 0
    started = false
    @intf.on_signal "LongTaskStart" do
      started = true
    end
    # Same as intf.on_signal("LongTaskEnd"), just the old way
    @intf.on_signal @obj.bus, "LongTaskEnd" do
      counter += 1
    end
    @obj.LongTaskBegin 3
    quitter = Thread.new do
      DBus.logger.debug "sleep before quit"
      sleep 1
      DBus.logger.debug "will quit"
      @loop.quit
    end
    @loop.run
    quitter.join

    assert_equal true, started
    assert_equal 1, counter
    assert_raise(ArgumentError) {@intf.on_signal } # not enough
    assert_raise(ArgumentError) {@intf.on_signal 'to', 'many', 'yarrrrr!'}
  end

  def test_too_many_rules
    100.times do
      @obj.on_signal "Whichever" do
        puts "not called"
      end
    end
  end

  def test_removing_a_nonexistent_rule
    @obj.on_signal "DoesNotExist"
  end
end
