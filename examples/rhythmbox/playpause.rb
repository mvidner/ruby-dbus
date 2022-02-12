#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"
bus = DBus::SessionBus.instance
# get a rb object
proxy = bus.introspect("org.gnome.Rhythmbox", "/org/gnome/Rhythmbox/Player")
proxyi = proxy["org.gnome.Rhythmbox.Player"]

# register for signals

mr = DBus::MatchRule.new
mr.type = "signal"
mr.interface = "org.gnome.Rhythmbox.Player"
mr.path = "/org/gnome/Rhythmbox/Player"
bus.add_match(mr) do |msg, first_param|
  print "#{msg.member} "
  puts first_param
end

proxyi.playPause(true)

main = DBus::Main.new
main << bus
main.run
