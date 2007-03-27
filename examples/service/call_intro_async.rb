#!/usr/bin/ruby

require 'dbus'
Thread.abort_on_exception = true

bus = DBus.session_bus
proxy = bus.introspect("org.ruby.service", "/org/ruby/MyInstance")
proxy["org.ruby.MyInterface"].MyMethod("ASV?!?!!") do |msg, ret|
  puts "MyMethod(\"ASV?!?!!\") returned #{ret.inspect}"
  exit
end

puts "Doing some computation here."

loop { bus.process(bus.wait_for_message) }

