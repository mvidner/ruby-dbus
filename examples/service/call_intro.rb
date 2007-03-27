#!/usr/bin/ruby

require 'dbus'
Thread.abort_on_exception = true

bus = DBus.session_bus
proxy = bus.introspect("org.ruby.service", "/org/ruby/MyInstance")
r = proxy["org.ruby.MyInterface"].MyMethod("kikoooooo service!")
puts "MyMethod(\"hi there!\") returned #{r.inspect}"

loop { bus.process(bus.wait_for_message) }

