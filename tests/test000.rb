#!/usr/bin/ruby

require 'dbus'

bus = DBus::Bus::get(DBus::Bus::SESSION)

signal = DBus::Message.new_signal("/test/signal/Object", "test.signal.Type", "Test")

