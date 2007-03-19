#!/usr/bin/ruby

require 'dbus'

d = if ARGV.member?("--system")
      DBus::Connection.new("unix=/var/run/dbus/system_bus_socket")
    else
      DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
    end
d.connect

puts "\t" + d.proxy.ListNames.join("\n\t")

