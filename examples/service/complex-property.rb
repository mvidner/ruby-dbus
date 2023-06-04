#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

# Complex property
class Test < DBus::Object
  dbus_interface "net.vidner.Scratch" do
    dbus_attr_reader :progress, "(stttt)"
  end

  def initialize(opath)
    @progress = ["working", 1, 0, 100, 42].freeze
    super(opath)
  end
end

bus = DBus::SessionBus.instance
bus.object_server.export(Test.new("/net/vidner/Scratch"))
bus.request_name("net.vidner.Scratch")
DBus::Main.new.tap { |m| m << bus }.run
