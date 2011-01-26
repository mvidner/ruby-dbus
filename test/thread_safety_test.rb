#!/usr/bin/env ruby
# Test thread safety
require "test/unit"
require "dbus"

def d(msg)
  puts "#{$$} #{msg}" if $DEBUG
end

class ThreadSafetyTest < Test::Unit::TestCase
  def setup
    @session_bus = DBus::ASessionBus.new(:threaded => true)
    svc = @session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.SampleInterface"
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
