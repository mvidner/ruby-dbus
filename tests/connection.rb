#!/usr/bin/ruby

require 'dbus'

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
buf = "l\001\000\001\034\000\000\000\002\000\000\000\200\000\000\000\001\001o\000\025\000\000\000/org/freedesktop/DBus\000\000\000\006\001s\000\024\000\000\000org.freedesktop.DBus\000\000\000\000\002\001s\000\024\000\000\000org.freedesktop.DBus\000\000\000\000\003\001s\000\v\000\000\000RequestName\000\000\000\000\000\b\001g\000\002su\000\022\000\000\000test.signal.source\000\000\002\000\000\000"
p DBus::Message.new.unmarshall(buf)
p d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)

