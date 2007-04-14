#!/usr/bin/ruby

require 'dbus'
bus = DBus.session_bus
# get a rb object
proxy = bus.introspect("org.gnome.Rhythmbox", "/org/gnome/Rhythmbox/Player")
proxyi = proxy["org.gnome.Rhythmbox.Player"]

# register for signals

mr = DBus::MatchRule.new
mr.type = "signal"
mr.interface = "org.gnome.Rhythmbox.Player"
mr.path = "/org/gnome/Rhythmbox/Player"
bus.add_match(mr) do |msg, first_param|
  print msg.member + " "
  puts first_param
end

proxyi.playPause(true)

m = DBus::Main.new
m << bus
m.run

