#!/usr/bin/ruby
# Test marshalling an array of variants
# https://trac.luon.net/ruby-dbus/ticket/30
require "dbus"
session_bus = DBus::SessionBus.instance
svc = session_bus.service("org.ruby.service")
obj = svc.object("/org/ruby/MyInstance")
obj.introspect                  # necessary
choices = []
choices << ['s', 'Plan A']
choices << ['s', 'Plan B']
obj.default_iface = "org.ruby.Ticket30"
p obj.Sybilla(choices)
