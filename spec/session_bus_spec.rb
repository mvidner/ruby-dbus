#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

describe DBus::ASessionBus do
  subject(:dbus_session_bus_address) { "unix:abstract=/tmp/dbus-foo,guid=123" }

  describe "#session_bus_address" do
    around(:each) do |example|
      @original_dbus_session_bus_address = ENV["DBUS_SESSION_BUS_ADDRESS"]
      example.call
      ENV["DBUS_SESSION_BUS_ADDRESS"] = @original_dbus_session_bus_address
    end

    context "when DBUS_SESSION_BUS_ADDRESS env is surrounded by quotation marks" do
      it "returns session bus address without single quotation marks" do
        ENV["DBUS_SESSION_BUS_ADDRESS"] = "'#{dbus_session_bus_address}'"
        expect(DBus::ASessionBus.session_bus_address).to eq(dbus_session_bus_address)
      end

      it "returns session bus address without double quotation marks" do
        ENV["DBUS_SESSION_BUS_ADDRESS"] = "\"#{dbus_session_bus_address}\""
        expect(DBus::ASessionBus.session_bus_address).to eq(dbus_session_bus_address)
      end
    end

    context "when DBUS_SESSION_BUS_ADDRESS env is not surrounded by any quotation marks" do
      it "returns session bus address as it is" do
        ENV["DBUS_SESSION_BUS_ADDRESS"] = dbus_session_bus_address
        expect(DBus::ASessionBus.session_bus_address).to eq(dbus_session_bus_address)
      end
    end
  end

  describe "#address_from_file" do
    let(:session_bus_file_path) { /\.dbus\/session-bus\/baz-\d/ }

    before do
      # mocks of files for address_from_file method
      machine_id_path = File.expand_path("/etc/machine-id", __FILE__)
      expect(Dir).to receive(:[]).with(any_args) {[machine_id_path] }
      expect(File).to receive(:read).with(machine_id_path) { "baz" }
      expect(File).to receive(:exists?).with(session_bus_file_path) { true }
    end

    around(:each) do |example|
      with_env("DISPLAY", ":0.0") do
        example.call
      end
    end

    context "when DBUS_SESSION_BUS_ADDRESS from file is surrounded by quotation marks" do

      it "returns session bus address without single quotation marks" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-EOS.gsub(/^\s*/, '') }
          DBUS_SESSION_BUS_ADDRESS='#{dbus_session_bus_address}'
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        EOS
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end

      it "returns session bus address without double quotation marks" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-EOS.gsub(/^\s*/, '') }
          DBUS_SESSION_BUS_ADDRESS="#{dbus_session_bus_address}"
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        EOS
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end
    end

    context "when DBUS_SESSION_BUS_ADDRESS from file is not surrounded by any quotation marks" do
      it "returns session bus address as it is" do
        expect(File).to receive(:open).with(session_bus_file_path) { <<-EOS.gsub(/^\s*/, '') }
          DBUS_SESSION_BUS_ADDRESS=#{dbus_session_bus_address}
          DBUS_SESSION_BUS_PID=12345
          DBUS_SESSION_BUS_WINDOWID=12345678
        EOS
        expect(DBus::ASessionBus.address_from_file).to eq(dbus_session_bus_address)
      end
    end
  end
end
