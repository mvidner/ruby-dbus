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
# method call sender=:1.3 -> dest=org.gnome.Rhythmbox path=/org/gnome/Rhythmbox/Player; interface=org.gnome.Rhythmbox.Player; member=playPause

m = DBus::Message.new(DBus::Message::METHOD_CALL)
m.path = "/org/gnome/Rhythmbox/Player"
m.interface = "org.gnome.Rhythmbox.Player"
m.destination = "org.gnome.Rhythmbox"
m.member = "playPause"
m.sender = d.unique_name
m.add_param(DBus::Type::BOOLEAN, false)
str = m.marshall
d.send(str)

puts "Return to quit."
gets
