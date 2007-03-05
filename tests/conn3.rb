#!/usr/bin/ruby

require 'dbus'

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect

message = DBus::Message.new
message.message_type = DBus::Message::METHOD_CALL
message.serial = 1
message.path = "/org/freedesktop/DBus"
message.destination = "org.freedesktop.DBus"
message.interface = "org.freedesktop.DBus"
message.member = "Hello"

d.send(message.marshall)
d.send("\0\0") # ?? why ?
s = d.read(90) # knowing 90 is cheating

p s

message = DBus::Message.new
message.message_type = DBus::Message::METHOD_CALL
message.serial = 1
message.path = "/org/freedesktop/DBus"
message.interface = "org.freedesktop.DBus.Peer"
message.member = "Ping"

d.send(message.marshall)

while c = d.read(10)
  p c
end
