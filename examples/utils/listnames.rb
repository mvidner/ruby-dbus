#!/usr/bin/ruby

require 'dbus'

d = if ARGV.member?("--system")
  DBus::SystemBus.instance
else
  DBus::SessionBus.instance
end
d.proxy.ListNames[0].each{ |n| puts "\t#{n}" }

