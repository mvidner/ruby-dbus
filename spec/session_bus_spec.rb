#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ASystemBus do
  describe "#initialize" do
    it "will use DBUS_SYSTEM_BUS_ADDRESS or the well known address" do
      expect(ENV)
        .to receive(:[])
        .with("DBUS_SYSTEM_BUS_ADDRESS")
        .and_return(nil)
      expect(DBus::MessageQueue)
        .to receive(:new)
        .with("unix:path=/var/run/dbus/system_bus_socket")
      expect_any_instance_of(described_class).to receive(:send_hello)

      described_class.new
    end
  end
end

describe DBus::ASessionBus do
  subject(:dbus_session_bus_address) { "unix:abstract=/tmp/dbus-foo,guid=123" }

  describe "#session_bus_address" do
    around(:each) do |example|
      @original_dbus_session_bus_address = ENV["DBUS_SESSION_BUS_ADDRESS"]
      example.call
      ENV["DBUS_SESSION_BUS_ADDRESS"] = @original_dbus_session_bus_address
    end

    it "returns DBUS_SESSION_BUS_ADDRESS as it is" do
      ENV["DBUS_SESSION_BUS_ADDRESS"] = dbus_session_bus_address
      expect(DBus::ASessionBus.session_bus_address).to eq(dbus_session_bus_address)
    end

    it "uses launchd on macOS when ENV and file fail" do
      ENV["DBUS_SESSION_BUS_ADDRESS"] = nil
      expect(described_class).to receive(:address_from_file).and_return(nil)
      expect(DBus::Platform).to receive(:macos?).and_return(true)

      expect(described_class.session_bus_address).to start_with "launchd:"
    end

    it "raises a readable exception when all addresses fail" do
      ENV["DBUS_SESSION_BUS_ADDRESS"] = nil
      expect(described_class).to receive(:address_from_file).and_return(nil)
      expect(DBus::Platform).to receive(:macos?).and_return(false)

      expect { described_class.session_bus_address }.to raise_error(NotImplementedError, /Cannot find session bus/)
    end
  end

  describe "#address_from_file" do
    let(:session_bus_file_path) { %r{\.dbus/session-bus/baz-\d} }

    before do
      # mocks of files for address_from_file method
      machine_id_path = File.expand_path("/etc/machine-id", __dir__)
      expect(Dir).to receive(:[]).with(any_args) { [machine_id_path] }
      expect(File).to receive(:read).with(machine_id_path) { "baz" }
      expect(File).to receive(:exist?).with(session_bus_file_path) { true }
    end

    around(:each) do |example|
      with_env("DISPLAY", ":0.0") do
        example.call
      end
    end

    context "when DBUS_SESSION_BUS_ADDRESS from file is surrounded by quotation marks" do
      it "returns session bus address without single quotation marks" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-TEXT.gsub(/^\s*/, "") }
          DBUS_SESSION_BUS_ADDRESS='#{dbus_session_bus_address}'
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        TEXT
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end

      it "returns session bus address without double quotation marks" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-TEXT.gsub(/^\s*/, "") }
          DBUS_SESSION_BUS_ADDRESS="#{dbus_session_bus_address}"
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        TEXT
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end
    end

    context "when DBUS_SESSION_BUS_ADDRESS from file is not surrounded by any quotation marks" do
      it "returns session bus address as it is" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-TEXT.gsub(/^\s*/, "") }
          DBUS_SESSION_BUS_ADDRESS=#{dbus_session_bus_address}
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        TEXT
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end
    end
  end
end
