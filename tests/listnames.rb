#!/usr/bin/ruby

require 'dbus'

$introspect = false
$system = false
if ARGV.member?("--introspect")
  $introspect = true
end
if ARGV.member?("--system")
  $system = true
end
Thread.abort_on_exception = true
d = nil
if $system
d = DBus::Connection.new("unix=/var/run/dbus/system_bus_socket")
else
d = DBus::Connection.new(ENV["DBUS_SESSION_BUS_ADDRESS"])
end
d.connect
Thread.new do
  loop do 
    m = d.wait_for_msg
    d.process(m)
  end
end
#d.request_name("test.signal.source", DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
# method call sender=:1.3 -> dest=org.gnome.Rhythmbox path=/org/gnome/Rhythmbox/Player; interface=org.gnome.Rhythmbox.Player; member=playPause

m = DBus::Message.new(DBus::Message::METHOD_CALL)
m.path = "/org/freedesktop/DBus"
m.interface = "org.freedesktop.DBus"
m.destination = "org.freedesktop.DBus"
m.member = "ListNames"
m.sender = d.unique_name
str = m.marshall
d.send(str)

d.on_return(m) do |rmsg, ret|
  puts "ListNames:"
  ret.each do |el|
    puts "\t#{el}"
    next if el == d.unique_name
    # A way to guess object path cleanly ?
    if $introspect and not el =~ /^:/
      m = DBus::Message.new(DBus::Message::METHOD_CALL)
      m.path = "/" + el.gsub(".", "/")
      m.interface = "org.freedesktop.DBus.Introspectable"
      m.destination = el
      m.member = "Introspect"
      m.sender = d.unique_name
      d.send(m.marshall)
      d.on_return(m) do |rmsg, inret|
        puts "#{el}.Introspect():"
        puts inret
      end
    end
  end
end

$stdin.gets

