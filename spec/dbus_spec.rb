#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus do
  describe ".session_bus", tag_bus: true do
    it "returns a BusConnection" do
      expect(DBus.session_bus).to be_a(DBus::BusConnection)
    end
  end

  describe ".system_bus" do
    # coverage obsession: mock it out,
    # system bus may not exist during RPM builds
    it "calls SystemBus.instance" do
      expect(DBus::SystemBus).to receive(:instance)
      DBus.system_bus
    end
  end
end
