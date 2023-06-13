#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::PeerConnection do
  let(:address) { ENV["DBUS_SESSION_BUS_ADDRESS"] }
  subject { described_class.new(address) }

  describe "#peer_service" do
    it "returns a PeerService with a nil name" do
      svc = subject.peer_service
      expect(svc).to be_a(DBus::ProxyService)
      expect(svc.name).to be_nil
    end
  end

  describe "#add_match, #remove_match" do
    it "doesn't crash trying to call AddMatch, RemoveMatch" do
      mr = DBus::MatchRule.new
      mr.member = "StateUpdated"
      mr.interface = "org.PulseAudio.Core1.Device"
      handler = ->(_msg) {}

      # Cheating a bit with the mocking:
      # a PulseAudio peer connection would error with
      # > DBus::Error: Method "AddMatch" with signature "s" on interface
      # > "org.freedesktop.DBus" doesn't exist
      # but here we do have a bus at the other end, which replies with
      # > DBus::Error: Client tried to send a message other than Hello without being registered
      # where "registering" is a libdbus-1 thing meaning "internal bookkeeping and send Hello"
      expect { subject.add_match(mr, &handler) }.to_not raise_error
      expect { subject.remove_match(mr) }.to_not raise_error
    end
  end
end
