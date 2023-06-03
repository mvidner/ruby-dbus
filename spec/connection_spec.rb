#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::PeerConnection do
  describe "#peer_service" do
    it "returns a PeerService with a nil name" do
      address = ENV["DBUS_SESSION_BUS_ADDRESS"]
      pconn = described_class.new(address)
      svc = pconn.peer_service
      expect(svc).to be_a(DBus::ProxyService)
      expect(svc.name).to be_nil
    end
  end
end
