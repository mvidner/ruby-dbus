#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

if ARGV.size < 2
  puts "Usage:"
  puts "notify.rb \"title\" \"body\""
  exit
end

d = DBus::SessionBus.instance
o = d["org.freedesktop.Notifications"]["/org/freedesktop/Notifications"]

i = o["org.freedesktop.Notifications"]

i.Notify("notify.rb", 0, "info", ARGV[0], ARGV[1], [], {}, 2000) do |ret, param|
end
