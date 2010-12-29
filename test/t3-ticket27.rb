#!/usr/bin/env ruby
# Test passing a particular struct array through a variant
# https://trac.luon.net/ruby-dbus/ticket/27
require "dbus"
session_bus = DBus::ASessionBus.new
svc = session_bus.service("org.ruby.service")
obj = svc.object("/org/ruby/MyInstance")
obj.introspect                  # necessary
obj.default_iface = "org.ruby.SampleInterface"
# The bug is probably alignment related so whether it triggers
# depends also on the combined length of service, interface,
# and method names. Luckily here it works out.
triple = ['a(uuu)', []]
obj.test_variant(triple)
quadruple = ['a(uuuu)', []]     # a(uuu) works fine
# The bus disconnects us because of malformed message,
# code 12: DBUS_INVALID_TOO_MUCH_DATA
obj.test_variant(quadruple)
