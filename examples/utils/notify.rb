#!/usr/bin/ruby

require 'dbus'

d = DBus.session_bus
o = d.service("org.freedesktop.Notifications").object("/org/freedesktop/Notifications")
o.introspect

i = o["org.freedesktop.Notifications"]
i.Notify('notify.rb', 0, 'info', 'Hi there', 'Some interesting body', [], {}, -1) do |ret, param|
  p param
  exit
end

loop { d.process(d.wait_for_message) }


