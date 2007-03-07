#!/usr/bin/ruby

require 'dbus'
require 'thread'

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
Thread.new do
  loop do 
    m = d.wait_for_msg
    puts "INPUT: #{m.inspect}"
  end
end

m = DBus::Message.new(DBus::Message::SIGNAL)
m.path = "/test/signal/Object"
m.interface = "test.signal.Type"
m.member = "Test"
m.sender = d.unique_name
d.send(m.marshall)

puts "Return to quit."
gets
