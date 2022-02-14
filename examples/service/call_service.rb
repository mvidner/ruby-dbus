#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

session_bus = DBus::SessionBus.instance

ruby_srv = session_bus.service("org.ruby.service")

# Get the object from this service
player = ruby_srv.object("/org/ruby/MyInstance")

player.default_iface = "org.ruby.SampleInterface"
player.test_variant(["s", "coucou"])
player.on_signal("SomethingJustHappened") do |u, v|
  puts "SomethingJustHappened: #{u} #{v}"
end
player.hello("Hey", "there!")
p player["org.ruby.AnotherInterface"].Reverse("Hello world!")

main = DBus::Main.new
main << session_bus
main.run
