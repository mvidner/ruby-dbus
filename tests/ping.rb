#!/usr/bin/ruby

require 'dbus'

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
Thread.new do
  loop do 
    m = d.wait_for_msg
    puts "INPUT: #{m.inspect}"
  end
end
d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
d.ping

puts "Return to quit."
gets
