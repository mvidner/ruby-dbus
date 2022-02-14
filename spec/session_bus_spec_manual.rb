#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ASessionBus do
  context "when DBUS_SESSION_BUS_ADDRESS is unset in ENV (Issue#4)" do
    ENV.delete "DBUS_SESSION_BUS_ADDRESS"

    it "can connect" do
      bus = DBus::ASessionBus.new
      svc = bus.service("org.freedesktop.DBus")
      expect(svc.exists?).to be true
    end
  end
end
