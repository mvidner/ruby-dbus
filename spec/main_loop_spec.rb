#!/usr/bin/env rspec
# frozen_string_literal: true

# Test the main loop
require_relative "spec_helper"
require "dbus"

describe "DBus.logger" do
  it "will log debug messages if $DEBUG is true" do
    logger_old = DBus.logger
    DBus.logger = nil
    debug_old = $DEBUG
    $DEBUG = true

    DBus.logger.debug "this debug message will always be shown"

    $DEBUG = debug_old
    DBus.logger = logger_old
  end
end

describe "MainLoopTest" do
  before(:each) do
    @session_bus = DBus::ASessionBus.new
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.Loop"

    @loop = DBus::Main.new
    @loop << @session_bus
  end

  # Hack the library internals so that there is a delay between
  # sending a DBus call and listening for its reply, so that
  # the bus has a chance to join the server messages and a race is reproducible
  def call_lazily
    class << @session_bus
      alias_method :wait_for_message_orig, :wait_for_message
      def wait_for_message_lazy
        DBus.logger.debug "I am so lazy"
        sleep 1 # Give the server+bus a chance to join the messages
        wait_for_message_orig
      end
      alias_method :wait_for_message, :wait_for_message_lazy
    end

    yield

    # undo
    class << @session_bus
      remove_method :wait_for_message
      remove_method :wait_for_message_lazy
      alias_method :wait_for_message, :wait_for_message_orig
    end
  end

  def test_loop_quit(delay)
    @obj.on_signal "LongTaskEnd" do
      DBus.logger.debug "Telling loop to quit"
      @loop.quit
    end

    call_lazily do
      # The method will sleep the requested amount of seconds
      # (in another thread)  before signalling LongTaskEnd
      @obj.LongTaskBegin delay
    end

    # this thread will make the test fail if @loop.run does not return
    dynamite = Thread.new do
      DBus.logger.debug "Dynamite burning"
      sleep 2
      DBus.logger.debug "Dynamite explodes"
      # We need to raise in the main thread.
      # Simply raising here means the exception is ignored
      # (until dynamite.join which we don't call) or
      # (if abort_on_exception is set) it terminates the whole script.
      Thread.main.raise RuntimeError, "The main loop did not quit in time"
    end

    @loop.run
    DBus.logger.debug "Defusing dynamite"
    # if we get here, defuse the bomb
    dynamite.exit
    # remove signal handler
    @obj.on_signal "LongTaskEnd"
  end

  it "tests loop quit", slow: true do
    test_loop_quit 1
  end

  # https://bugzilla.novell.com/show_bug.cgi?id=537401
  it "tests loop drained socket" do
    test_loop_quit 0
  end
end
