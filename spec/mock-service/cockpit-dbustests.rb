#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../coverage_helper"
SimpleCov.command_name "Cockpit Tests (#{Process.pid})" if Object.const_defined? "SimpleCov"

# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)
require "dbus"

SERVICE_NAME = "org.rubygems.ruby_dbus.DBusTests"
ROOT_OPATH = "/otree/frobber"

class DBusTests < DBus::Object
  FROBBER_INTERFACE = "com.redhat.Cockpit.DBusTests.Frobber"

  dbus_interface FROBBER_INTERFACE do
    dbus_method :HelloWorld, "in greeting:s, out response:s" do |greeting|
      # TODO: return the same thing as the original implementation
      # and try substituting it?
      [format("Word! You said `%s'. I'm Skeleton, btw!", greeting)]
    end
  end
end

bus = DBus::SessionBus.instance
bus.object_server.export(DBusTests.new(ROOT_OPATH))
bus.request_name(SERVICE_NAME)
DBus::Main.new.tap { |m| m << bus }.run
