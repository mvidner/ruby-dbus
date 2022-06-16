#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::EmitsChangedSignal do
  describe "#initialize" do
    it "accepts a simple value" do
      expect(described_class.new(:const).value).to eq :const
    end

    it "avoids nil by asking the interface" do
      ifc = DBus::Interface.new("org.example.Foo")
      ifc.emits_changed_signal = described_class.new(:invalidates)

      expect(described_class.new(nil, interface: ifc).value).to eq :invalidates
    end

    it "fails for unknown value" do
      expect { described_class.new(:huh) }.to raise_error(ArgumentError, /Seen :huh/)
    end

    it "fails for 2 nils" do
      expect { described_class.new(nil, interface: nil) }.to raise_error(ArgumentError, /Both/)
    end
  end
end
