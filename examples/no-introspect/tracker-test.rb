#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Trivial network interface lister using NetworkManager.
# NetworkManager does not support introspection, so the api is not that sexy.

require "dbus"

bus = DBus::SessionBus.instance

tracker_service = bus.service("org.freedesktop.Tracker")
tracker_manager = tracker_service.object("/org/freedesktop/tracker")
poi = DBus::ProxyObjectInterface.new(tracker_manager, "org.freedesktop.Tracker.Files")
poi.define_method("GetMetadataForFilesInFolder", "in live_query_id:i, in uri:s, in fields:as, out values:aas")
p poi.GetMetadataForFilesInFolder(-1, "#{ENV["HOME"]}/Desktop", ["File:Name", "File:Size"])
