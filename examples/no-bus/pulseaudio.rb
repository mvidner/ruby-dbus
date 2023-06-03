#! /usr/bin/env ruby
# frozen_string_literal: true

# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "dbus"

def peer_address
  bus = DBus::SessionBus.instance
  svc = bus["org.PulseAudio1"]
  obj = svc["/org/pulseaudio/server_lookup1"]
  ifc = obj["org.PulseAudio.ServerLookup1"]
  adr = ifc["Address"]
  puts "PA address: #{adr}"
  adr
end

address = peer_address
begin
  conn = DBus::PeerConnection.new(address)
rescue Errno::ENOENT
  puts "Address exists but could not connect; telling PA to load the protocol"
  system "pactl load-module module-dbus-protocol"
  conn = DBus::PeerConnection.new(address)
end
no_svc = conn.peer_service
obj = no_svc["/org/pulseaudio/core1"]
ifc = obj["org.PulseAudio.Core1"]
puts "PA version: #{ifc["Version"]}"
