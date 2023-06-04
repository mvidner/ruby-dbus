#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::BusConnection do
  let(:bus) { DBus::ASessionBus.new }

  # deprecated method
  describe "#request_service", tag_bus: true, tag_deprecated: true do
    context "when the name request succeeds" do
      # Formerly it returned Service, now ObjectServer takes its role.
      # Replacement: server = bus.object_server; bus.request_name(name)
      it "returns something which can export objects" do
        name = "org.rubygems.ruby_dbus.RequestServiceTest"
        server = bus.request_service(name)
        expect(server).to respond_to(:export)
        bus.proxy.ReleaseName(name)
      end
    end

    context "when the name is taken already", tag_service: true do
      # formerly it returned Service, now ObjectServer takes its role
      it "raises NameRequestError... too late" do
        name = "org.ruby.service"
        expect do
          bus.request_service(name)
          _unrelated_call = bus.proxy.GetId.first
        end.to raise_error(DBus::Connection::NameRequestError)
        # The call fails but it means we did not get the name RIGHT AWAY
        # but we are still queued to get it as soon as the current owner
        # gives it up.
        # So even now we have to the bus to remove us from the queue
        bus.proxy.ReleaseName(name)
      end
    end

    context "when we're not allowed to own the name", tag_system_bus: true do
      let(:bus) { DBus::ASystemBus.new }
      it "raises an error... too late" do
        name = "org.rubygems.ruby_dbus.NotAllowedToOwnThisNameAnyway"
        expect do
          bus.request_service(name)
          _unrelated_call = bus.proxy.GetId.first
        end.to raise_error(DBus::Error, /not allowed to own the service/)
      end
    end
  end

  describe "#request_name", tag_bus: true do
    context "when the name request succeeds" do
      it "returns something which can export objects" do
        name = "org.rubygems.ruby_dbus.RequestNameTest"
        expect { bus.request_name(name) }.to_not raise_error
        bus.proxy.ReleaseName(name)
      end
    end

    context "when the name is taken already", tag_service: true do
      # formerly it returned Service, now ObjectServer takes its role
      it "raises NameRequestError" do
        name = "org.ruby.service"
        expect do
          # flags: avoid getting the name sometime later, unexpectedly
          bus.request_name(name, flags: DBus::Connection::NAME_FLAG_DO_NOT_QUEUE)
        end.to raise_error(DBus::Connection::NameRequestError)
      end
    end

    context "when we're not allowed to own the name", tag_system_bus: true do
      let(:bus) { DBus::ASystemBus.new }
      it "raises an error... too late" do
        name = "org.rubygems.ruby_dbus.NotAllowedToOwnThisNameAnyway"
        expect do
          bus.request_name(name)
        end.to raise_error(DBus::Error, /not allowed to own the service/)
      end
    end
  end
end
