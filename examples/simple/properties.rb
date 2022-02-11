#! /usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

bus = DBus::SystemBus.instance
nm_service = bus["org.freedesktop.NetworkManager"]
network_manager_object = nm_service["/org/freedesktop/NetworkManager"]
nm_iface = network_manager_object["org.freedesktop.NetworkManager"]

# read a property
enabled = nm_iface["WirelessEnabled"]
if enabled
  puts "Wireless is enabled"
else
  puts "Wireless is disabled"
end
puts "Toggling wireless"
# write a property
nm_iface["WirelessEnabled"] = !enabled
