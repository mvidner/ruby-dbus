#!/usr/bin/env rspec
# Test that a client survives various error cases
require_relative "spec_helper"
require "dbus"

describe "ClientRobustnessTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
  end

  context "when the object path is invalid" do
    it "tells the user the path is invalid" do
      # user mistake, should be "/org/ruby/MyInstance"
      expect { @svc.object("org.ruby.MyInstance") }.to raise_error(DBus::Error)
    end
  end
end
