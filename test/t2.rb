#!/usr/bin/env ruby
# test passing an array through a variant
require "dbus"
session_bus = DBus::SessionBus.instance
svc = session_bus.service("org.ruby.service")
obj = svc.object("/org/ruby/MyInstance")
obj.introspect                  # necessary
obj.default_iface = "org.ruby.SampleInterface"
obj.test_variant(["as", ["coucou", "kuku"]])
