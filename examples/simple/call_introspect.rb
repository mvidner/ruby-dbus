#!/usr/bin/ruby

require "dbus"

system_bus = DBus::session_bus

# Get the Rhythmbox service
rhythmbox = system_bus.service("org.gnome.Rhythmbox")

# Get the object from this service
player = rhythmbox.object("/org/gnome/Rhythmbox/Player")

# Introspect it
player.introspect
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
player.on_signal("elapsedChanged") do |*u|
  puts "elapsedChanged: #{u}"
end

loop { system_bus.process(system_bus.wait_for_message) }

