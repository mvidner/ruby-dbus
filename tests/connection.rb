#!/usr/bin/ruby

require 'dbus'

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
p d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
exit

