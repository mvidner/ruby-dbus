#!/usr/bin/ruby

require 'dbus'
the_serial = nil
Thread.abort_on_exception = true

d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
d.connect
Thread.new do
  loop do 
    m = d.wait_for_msg
    if the_serial and m.serial == the_serial
      puts "Listing registered dbus names:"
      m.params[0].each do |el|
        p el
      end
    end
  end
end
d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
# method call sender=:1.3 -> dest=org.gnome.Rhythmbox path=/org/gnome/Rhythmbox/Player; interface=org.gnome.Rhythmbox.Player; member=playPause

m = DBus::Message.new(DBus::Message::METHOD_CALL)
the_serial = m.serial
m.path = "/org/freedesktop/DBus"
m.interface = "org.freedesktop.DBus"
m.destination = "org.freedesktop.DBus"
m.member = "ListNames"
m.sender = d.unique_name
str = m.marshall
d.send(str)

puts "Return to quit."
gets
