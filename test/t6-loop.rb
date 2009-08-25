#!/usr/bin/env ruby
# Test the main loop
require "test/unit"
require "dbus"

def d(msg)
  puts msg if $DEBUG
end

class MainLoopTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::SessionBus.instance
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.Loop"

    @loop = DBus::Main.new
    @loop << session_bus
  end
#  def teardown ?

  def test_loop_quit
    @obj.on_signal "LongTaskEnd" do
      d "Telling loop to quit"
      @loop.quit
    end

    # The method will sleep the requested amount of seconds (in another thread)
    # before signalling LongTaskEnd
    @obj.LongTaskBegin 1
    # this thread will make the test fail if @loop.run does not return
    dynamite = Thread.new do
      d "Dynamite burning"
      sleep 2
      d "Dynamite explodes"
      # We need to raise in the main thread.
      # Simply raising here means the exception is ignored
      # (until dynamite.join which we don't call) or
      # (if abort_on_exception is set) it terminates the whole script.
      Thread.main.raise RuntimeError, "The main loop did not quit in time"
    end
    
    @loop.run
    # if we get here, defuse the bomb
    dynamite.exit
  end
end
