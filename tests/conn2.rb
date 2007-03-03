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

p "l\1\0\1\0\0\0\0\1\0\0\0n\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\5\0\0\0Hello\0\0\0"
str = message.marshall
p str

msgsig = "yyyyuua(yyv)"
p DBus::PacketUnmarshaller.new(msgsig, str, DBus::LIL_END).parse

