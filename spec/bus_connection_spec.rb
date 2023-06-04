#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::BusConnection do
  let(:bus) { DBus::ASessionBus.new }

  # deprecated method
  describe "#request_service", tag_bus: true, tag_deprecated: true do
    context "when the name request succeeds" do
      # formerly it returned Service, now ObjectServer takes its role
      it "returns something which can export objects" do
        server = bus.request_service("org.rubygems.ruby_dbus.RequestServiceTest")
        expect(server).to respond_to(:export)
      end
    end

    context "when the name is taken already", tag_service: true do
      # formerly it returned Service, now ObjectServer takes its role
      it "returns something which can export objects" do
        expect do
          bus.request_service("org.ruby.service")
          _unrelated_call = bus.proxy.GetId.first
        end.to raise_error(DBus::Connection::NameRequestError)
      end
    end
  end
end
