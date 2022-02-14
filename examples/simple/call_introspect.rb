#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

session_bus = DBus::SessionBus.instance

# Get the Rhythmbox service
rhythmbox = session_bus.service("org.gnome.Rhythmbox")

# Get the object from this service
player = rhythmbox.object("/org/gnome/Rhythmbox/Player")

if player.has_iface? "org.gnome.Rhythmbox.Player"
  puts "We have Rhythmbox Player interface"
end

player_with_iface = player["org.gnome.Rhythmbox.Player"]
p player_with_iface.getPlayingUri

# Maybe support default_iface=(iface_str) on an ProxyObject, so
# that this is possible?
player.default_iface = "org.gnome.Rhythmbox.Player"
puts "default_iface test:"
p player.getPlayingUri
player.on_signal("elapsedChanged") do |u|
  puts "elapsedChanged: #{u}"
end

main = DBus::Main.new
main << session_bus
main.run
