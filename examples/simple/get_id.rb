#! /usr/bin/env ruby

# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../../lib", __FILE__)

require "dbus"

bus = DBus::SystemBus.instance
driver_svc = bus["org.freedesktop.DBus"]
# p driver_svc
driver_obj = driver_svc["/"]
# p driver_obj
driver_ifc = driver_obj["org.freedesktop.DBus"]
# p driver_ifc

bus_id = driver_ifc.GetId
puts "The system bus id is #{bus_id}"
