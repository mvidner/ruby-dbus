#!/usr/bin/ruby

require "dbus"

session_bus = DBus::SessionBus.instance

# Get the Rhythmbox service
ruby_srv = session_bus.service("org.ruby.service")

# Get the object from this service
player = ruby_srv.object("/org/ruby/MyInstance")

# Introspect it
player.introspect
player.default_iface = "org.ruby.SampleInterface"
player.on_signal("SomethingJustHappened") do |u, v|
  puts "SomethingJustHappened: #{u} #{v}"
end
player.hello("8=======D", "(_._)")
p player["org.ruby.AnotherInterface"].Reverse("Hello world!")

main = DBus::Main.new
main << session_bus
main.run

