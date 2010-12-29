#!/usr/bin/env ruby
# Test thread safety
require "test/unit"
require "dbus"

def d(msg)
  puts "#{$$} #{msg}" if $DEBUG
end

class ThreadSafetyTest < Test::Unit::TestCase
  def setup
    ENV["DBUS_THREADED_ACCESS"] = "1"
    @session_bus = DBus::ASessionBus.new
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  def teardown
    ENV.delete "DBUS_THREADED_ACCESS"
  end

  def test_thread_competition
    print "Thread competition: "
    jobs = []
    5.times do
      jobs << Thread.new do
        10.times do |i|
          print "#{i} "
          $stdout.flush
          assert_equal 42, @obj.the_answer[0]
          sleep 0.1 * rand
        end
      end
    end
    jobs.each do |thread| thread.join end
  end
end
