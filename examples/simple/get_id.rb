#! /usr/bin/env ruby
# frozen_string_literal: true

# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "dbus"

busname = ARGV.fetch(0, "system")
bus = busname == "session" ? DBus::SessionBus.instance : DBus::SystemBus.instance

driver_svc = bus["org.freedesktop.DBus"]
# p driver_svc
driver_obj = driver_svc["/"]
# p driver_obj
driver_ifc = driver_obj["org.freedesktop.DBus"]
# p driver_ifc

bus_id = driver_ifc.GetId
puts "The #{busname} bus id is #{bus_id}"
