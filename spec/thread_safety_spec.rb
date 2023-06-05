#!/usr/bin/env rspec
# frozen_string_literal: true

# Test thread safety
require_relative "spec_helper"
require "dbus"

class TestSignalRace < DBus::Object
  dbus_interface "org.ruby.ServerTest" do
    dbus_signal :signal_without_arguments
  end
end

# Run *count* threads all doing *body*, wait for their finish
def race_threads(count, &body)
  jobs = count.times.map do |j|
    Thread.new do
      Thread.current.abort_on_exception = true

      body.call(j)
    end
  end
  jobs.each(&:join)
end

# Repeat *count* times: { random sleep, *body* }, printing progress
def repeat_with_jitter(count, &body)
  count.times do |i|
    sleep 0.1 * rand
    print "#{i} "
    $stdout.flush

    body.call
  end
end

describe "thread safety" do
  context "R/W: when the threads call methods with return values" do
    it "it works with separate bus connections" do
      race_threads(5) do |_j|
        # use separate connections to avoid races
        bus = DBus::ASessionBus.new
        svc = bus.service("org.ruby.service")
        obj = svc.object("/org/ruby/MyInstance")
        obj.default_iface = "org.ruby.SampleInterface"

        repeat_with_jitter(10) do
          expect(obj.the_answer[0]).to eq(42)
        end
      end
      puts
    end
  end

  context "W/O: when the threads only send signals" do
    it "it works with a shared bus connection" do
      # shared connection
      bus = DBus::SessionBus.instance
      svc = bus.object_server
      obj = TestSignalRace.new "/org/ruby/Foo"
      svc.export obj

      race_threads(5) do |_j|
        repeat_with_jitter(10) do
          obj.signal_without_arguments
        end
      end

      svc.unexport(obj)
      puts
    end
  end
end
