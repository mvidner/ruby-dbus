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

  describe "#==" do
    it "is true for two different objects with the same value" do
      const_a = described_class.new(:const)
      const_b = described_class.new(:const)
      expect(const_a == const_b).to be true
    end
  end

  describe "#to_xml" do
    it "uses a string value" do
      expect(described_class.new(:const).to_xml)
        .to eq "    <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"const\"/>\n"
    end
  end

  describe "#to_s" do
    it "uses a string value" do
      expect(described_class.new(:const).to_s).to eq "const"
    end
  end
end

describe DBus::Interface do
  describe ".emits_changed_signal=" do
    it "only allows an EmitsChangedSignal as argument" do
      ifc = described_class.new("org.ruby.Interface")
      expect { ifc.emits_changed_signal = :const }.to raise_error(TypeError)
    end
  end
end
