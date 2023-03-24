#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# Pedantic full coverage test.
# The happy paths are covered via calling classes
describe DBus::RawMessage do
  describe ".endianness" do
    it "returns :little for 'l'" do
      expect(described_class.endianness("l")).to eq :little
    end

    it "returns :big for 'B'" do
      expect(described_class.endianness("B")).to eq :big
    end

    it "raises for other strings" do
      expect { described_class.endianness("m") }
        .to raise_error(DBus::InvalidPacketException, /Incorrect endianness/)
    end
  end

  describe "#align" do
    it "raises for values other than 1 2 4 8" do
      subject = described_class.new("l")
      expect { subject.align(3) }.to raise_error(ArgumentError)
      expect { subject.align(16) }.to raise_error(ArgumentError)
    end
  end
end
