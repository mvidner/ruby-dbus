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

puts "Waiting for volume changes, try adjusting it. Ctrl-C to exit."

vol_ifc = "org.PulseAudio.Core1.Device"
vol_member = "VolumeUpdated"
# PA needs explicit enabling of signals
ifc.ListenForSignal("#{vol_ifc}.#{vol_member}", [])

match_rule = DBus::MatchRule.new
match_rule.interface = vol_ifc
match_rule.member = vol_member
conn.add_match(match_rule) do |msg|
  # a single argument that is an array
  volumes = msg.params[0]
  puts "VolumeUpdated: #{volumes.join(", ")}"
end

loop = DBus::Main.new
loop << conn
loop.run
