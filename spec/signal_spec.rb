#!/usr/bin/env rspec
# frozen_string_literal: true

# Test the signal handlers
require_relative "spec_helper"
require "dbus"

def new_quitter(main_loop)
  Thread.new do
    DBus.logger.debug "sleep before quit"
    # FIXME: if we sleep for too long
    # the socket will be drained and we deadlock in a select.
    # It could be worked around by sending ourselves a Unix signal
    # (with a dummy handler) to interrupt the select
    sleep 1
    DBus.logger.debug "will quit"
    main_loop.quit
  end
end

describe "SignalHandlerTest" do
  before(:each) do
    @session_bus = DBus::ASessionBus.new
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.Loop"
    @intf = @obj["org.ruby.Loop"]

    @loop = DBus::Main.new
    @loop << @session_bus
  end

  # testing for commit 017c83 (kkaempf)
  it "tests overriding a handler", slow: true do
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

    quitter = new_quitter(@loop)
    @loop.run
    quitter.join

    expect(counter).to eq(1)
  end

  it "tests on signal overload", slow: true do
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
    quitter = new_quitter(@loop)
    @loop.run
    quitter.join

    expect(started).to eq(true)
    expect(counter).to eq(1)
    expect { @intf.on_signal }.to raise_error(ArgumentError) # not enough
    expect { @intf.on_signal "to", "many", "yarrrrr!" }.to raise_error(ArgumentError)
  end

  it "is possible to add signal handlers from within handlers", slow: true do
    ended = false
    @intf.on_signal "LongTaskStart" do
      @intf.on_signal "LongTaskEnd" do
        ended = true
      end
    end

    @obj.LongTaskBegin 3
    quitter = new_quitter(@loop)
    @loop.run
    quitter.join

    expect(ended).to eq(true)
  end

  it "tests too many rules" do
    100.times do
      @obj.on_signal "Whichever" do
        puts "not called"
      end
    end
  end

  it "tests removing a nonexistent rule" do
    @obj.on_signal "DoesNotExist"
  end

  describe DBus::ProxyObject do
    describe "#on_signal" do
      it "raises a descriptive error when the default_iface is wrong" do
        open_quote = RUBY_VERSION >= "3.4" ? "'" : "`"
        @obj.default_iface = "org.ruby.NoSuchInterface"
        expect { @obj.on_signal("Foo") {} }
          .to raise_error(NoMethodError, /undefined signal.*interface #{open_quote}org.ruby.NoSuchInterface'/)
      end
    end
  end
end
