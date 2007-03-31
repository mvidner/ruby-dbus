#!/usr/bin/ruby

require "dbus"

system_bus = DBus::session_bus

# Get the Rhythmbox service
ruby_srv = system_bus.service("org.ruby.service")

# Get the object from this service
player = ruby_srv.object("/org/ruby/MyInstance")

# Introspect it
player.introspect
player.default_iface = "org.ruby.SampleInterface"
player.hello("8=======D", "(_._)")

