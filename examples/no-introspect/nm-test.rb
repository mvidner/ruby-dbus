#!/usr/bin/ruby
#
# Trivial network interface lister using NetworkManager.
# NetworkManager does not support introspection, so the api is not that sexy.

require 'dbus'

bus = DBus::SystemBus.instance

nm_service = bus.service("org.freedesktop.NetworkManager")
nm_manager = nm_service.object("/org/freedesktop/NetworkManager")
poi = DBus::ProxyObjectInterface.new(nm_manager, "org.freedesktop.NetworkManager")
poi.define_method("getDevices", "")
p poi.getDevices


