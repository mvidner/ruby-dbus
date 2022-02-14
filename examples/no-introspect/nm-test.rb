#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Trivial network interface lister using NetworkManager.
# NetworkManager does not support introspection, so the api is not that sexy.

require "dbus"

bus = DBus::SystemBus.instance

nm_service = bus.service("org.freedesktop.NetworkManager")
nm_manager = nm_service.object("/org/freedesktop/NetworkManager")
poi = DBus::ProxyObjectInterface.new(nm_manager, "org.freedesktop.NetworkManager")
begin
  poi.define_method("getDevices", "") # NM 0.6
  p poi.getDevices
rescue Exception
  poi.define_method("GetDevices", "") # NM 0.7
  p poi.GetDevices
end
