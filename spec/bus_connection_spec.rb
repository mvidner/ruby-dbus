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

    # This only works with our special bus setup
    context "when we're not allowed to own the name", tag_limited_bus: true do
      it "raises an error... too late" do
        name = "org.rubygems.ruby_dbus.NobodyCanOwnThisName"
        expect do
          bus.request_service(name)
          _unrelated_call = bus.proxy.GetId.first
        end.to raise_error(DBus::Error, /not allowed to own the service/)
      end
    end
  end

  describe "#request_name", tag_bus: true do
    context "when the name request succeeds" do
      it "returns a success code" do
        name = "org.rubygems.ruby_dbus.RequestNameTest"
        expect(bus.request_name(name)).to eq DBus::Connection::REQUEST_NAME_REPLY_PRIMARY_OWNER
        # second time, considered also a success
        expect(bus.request_name(name)).to eq DBus::Connection::REQUEST_NAME_REPLY_ALREADY_OWNER
        bus.release_name(name)
      end
    end

    context "when the name is taken already", tag_service: true do
      it "raises NameRequestError" do
        name = "org.ruby.service"
        expect do
          bus.request_name(name)
        end.to raise_error(DBus::Connection::NameRequestError)
      end
    end

    context "when the name is taken already but we request queuing", tag_service: true do
      it "raises NameRequestError but we are queued" do
        name = "org.ruby.service"
        owning = nil
        # TODO: we do not expect the handlers to run
        bus.on_name_acquired { owning = true }
        bus.on_name_lost { owning = false }
        expect do
          bus.request_name(name, queue: true)
        end.to raise_error(DBus::Connection::NameRequestError)
        expect(bus.release_name(name)).to eq DBus::BusConnection::RELEASE_NAME_REPLY_RELEASED
      end
    end

    context "when we're not allowed to own the name", tag_limited_bus: true do
      it "raises an error" do
        name = "org.rubygems.ruby_dbus.NobodyCanOwnThisName"
        expect do
          bus.request_name(name)
        end.to raise_error(DBus::Error, /not allowed to own the service/)
      end
    end
  end
end
