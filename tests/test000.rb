#!/usr/bin/ruby

require 'dbusglue'

bus = DBus::Bus::get(DBus::Bus::SESSION)

bus.request_name("test.signal.source", DBUS_NAME_FLAG_REPLACE_EXISTING)

signal = DBus::Message.new_signal("/test/signal/Object", "test.signal.Type", "Test")

iter = signal.new_iter_append
iter.append_basic("coucou")

bus.send(signal, 0)
bus.flush
