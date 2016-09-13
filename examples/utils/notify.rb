#!/usr/bin/env ruby

require "dbus"

if ARGV.size < 2
  puts "Usage:"
  puts "notify.rb \"title\" \"body\""
  exit
end

d = DBus::SessionBus.instance
o = d.service("org.freedesktop.Notifications").object("/org/freedesktop/Notifications")
o.introspect

i = o["org.freedesktop.Notifications"]

i.Notify("notify.rb", 0, "info", ARGV[0], ARGV[1], [], {}, 2000) do |ret, param|
end

