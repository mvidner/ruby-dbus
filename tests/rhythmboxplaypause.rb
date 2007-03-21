#!/usr/bin/ruby

require 'dbus'
Thread.abort_on_exception = true

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
Thread.new do
  loop do 
    m = d.wait_for_message
    d.process(m)
  end
end

m = DBus::Message.new(DBus::Message::METHOD_CALL)
m.path = "/org/gnome/Rhythmbox/Player"
m.interface = "org.gnome.Rhythmbox.Player"
m.destination = "org.gnome.Rhythmbox"
m.member = "playPause"
m.sender = d.unique_name
m.add_param(DBus::Type::BOOLEAN, false)
d.send_sync(m) do |ret|
  p ret
end

