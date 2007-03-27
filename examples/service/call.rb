#!/usr/bin/ruby

require 'dbus'
Thread.abort_on_exception = true

bus = DBus.session_bus


po = DBus::ProxyObject.new(bus, "org.ruby.service", "/org/ruby/MyInstance")
intf = DBus::ProxyObjectInterface.new(po, "org.ruby.MyInterface")
intf.define_method(:MyMethod, "in mystring:s, out myret:s")

r = intf.MyMethod("hi there!")
puts "MyMethod(\"hi there!\") returned #{r.inspect}"

loop { bus.process(bus.wait_for_message) }


