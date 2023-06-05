#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# Pedantic full coverage test.
# The happy paths are covered via calling classes
describe DBus::Message do
  describe "#marshall" do
    it "raises when the object path is /org/freedesktop/DBus/Local" do
      m = DBus::Message.new(DBus::Message::SIGNAL)
      # the path is valid, it just must not be sent
      m.path = DBus::ObjectPath.new("/org/freedesktop/DBus/Local")
      m.interface = "org.example.spam"
      m.member = "Spam"

      expect { m.marshall }.to raise_error(RuntimeError, /Cannot send a message with the reserved path/)
    end
  end
end
