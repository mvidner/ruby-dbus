#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

RSpec.shared_examples "parses good data" do |cases|
  describe "parses all the instances of good test data" do
    cases.each_with_index do |(buffer, endianness, value), i|
      it "parses data ##{i}" do
        subject = described_class.new(buffer, endianness)
        # note the singleton [value],
        # unmarshall works on multiple signatures but we use one
        expect(subject.unmarshall(signature)).to eq([value])
      end
    end
  end
end

RSpec.shared_examples "reports bad data" do |cases|
  describe "reports all the instances of bad test data" do
    cases.each_with_index do |(buffer, endianness, exc_class, msg_re), i|
      it "reports data ##{i}" do
        subject = described_class.new(buffer, endianness)
        expect { subject.unmarshall(signature) }.to raise_error(exc_class, msg_re)
      end
    end
  end
end

# this is necessary because we do an early switch on the signature
RSpec.shared_examples "reports empty data" do
  it "reports empty data" do
    [:big, :little].each do |endianness|
      subject = described_class.new("", endianness)
      expect { subject.unmarshall(signature) }.to raise_error(DBus::IncompleteBufferException)
    end
  end
end

describe DBus::PacketUnmarshaller do
  context "BYTEs" do
    let(:signature) { "y" }
    good = [
      ["\x00", :little, 0x00],
      ["\x80", :little, 0x80],
      ["\xff", :little, 0xff],
      ["\x00", :big, 0x00],
      ["\x80", :big, 0x80],
      ["\xff", :big, 0xff]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "BOOLEANs" do
    let(:signature) { "b" }

    good = [
      ["\x01\x00\x00\x00", :little, true],
      ["\x00\x00\x00\x00", :little, false],
      ["\x00\x00\x00\x01", :big, true],
      ["\x00\x00\x00\x00", :big, false]
    ]
    include_examples "parses good data", good

    # TODO: InvalidPacketException is never rescued.
    # The other end is sending invalid data. Can we do better than crashing?
    # When we can test with peer connections, try it out.
    bad = [
      ["\x00\xff\xff\x00", :little, DBus::InvalidPacketException, /BOOLEAN must be 0 or 1, found/],
      ["\x00\xff\xff\x00", :big,    DBus::InvalidPacketException, /BOOLEAN must be 0 or 1, found/]
    ]
    include_examples "reports bad data", bad
    include_examples "reports empty data"
  end

  context "INT16s" do
    let(:signature) { "n" }

    good = [
      ["\x00\x00", :little, 0],
      ["\xff\x7f", :little, 32_767],
      ["\x00\x80", :little, -32_768],
      ["\xff\xff", :little, -1],
      ["\x00\x00", :big, 0],
      ["\x7f\xff", :big, 32_767],
      ["\x80\x00", :big, -32_768],
      ["\xff\xff", :big, -1]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "UINT16s" do
    let(:signature) { "q" }

    good = [
      ["\x00\x00", :little, 0],
      ["\xff\x7f", :little, 32_767],
      ["\x00\x80", :little, 32_768],
      ["\xff\xff", :little, 65_535],
      ["\x00\x00", :big, 0],
      ["\x7f\xff", :big, 32_767],
      ["\x80\x00", :big, 32_768],
      ["\xff\xff", :big, 65_535]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "INT32s" do
    let(:signature) { "i" }
    good = [
      ["\x00\x00\x00\x00", :little, 0],
      ["\xff\xff\xff\x7f", :little, 2_147_483_647],
      ["\x00\x00\x00\x80", :little, -2_147_483_648],
      ["\xff\xff\xff\xff", :little, -1],
      ["\x00\x00\x00\x00", :big, 0],
      ["\x7f\xff\xff\xff", :big, 2_147_483_647],
      ["\x80\x00\x00\x00", :big, -2_147_483_648],
      ["\xff\xff\xff\xff", :big, -1]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "UINT32s" do
    let(:signature) { "u" }
    good = [
      ["\x00\x00\x00\x00", :little, 0],
      ["\xff\xff\xff\x7f", :little, 2_147_483_647],
      ["\x00\x00\x00\x80", :little, 2_147_483_648],
      ["\xff\xff\xff\xff", :little, 4_294_967_295],
      ["\x00\x00\x00\x00", :big, 0],
      ["\x7f\xff\xff\xff", :big, 2_147_483_647],
      ["\x80\x00\x00\x00", :big, 2_147_483_648],
      ["\xff\xff\xff\xff", :big, 4_294_967_295]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "UNIX_FDs" do
    let(:signature) { "h" }
    good = [
      ["\x00\x00\x00\x00", :little, 0],
      ["\xff\xff\xff\x7f", :little, 2_147_483_647],
      ["\x00\x00\x00\x80", :little, 2_147_483_648],
      ["\xff\xff\xff\xff", :little, 4_294_967_295],
      ["\x00\x00\x00\x00", :big, 0],
      ["\x7f\xff\xff\xff", :big, 2_147_483_647],
      ["\x80\x00\x00\x00", :big, 2_147_483_648],
      ["\xff\xff\xff\xff", :big, 4_294_967_295]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "INT64s" do
    let(:signature) { "x" }
    good = [
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :little, 0],
      ["\xff\xff\xff\xff\xff\xff\xff\x7f", :little, 9_223_372_036_854_775_807],
      ["\x00\x00\x00\x00\x00\x00\x00\x80", :little, -9_223_372_036_854_775_808],
      ["\xff\xff\xff\xff\xff\xff\xff\xff", :little, -1],
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :big, 0],
      ["\x7f\xff\xff\xff\xff\xff\xff\xff", :big, 9_223_372_036_854_775_807],
      ["\x80\x00\x00\x00\x00\x00\x00\x00", :big, -9_223_372_036_854_775_808],
      ["\xff\xff\xff\xff\xff\xff\xff\xff", :big, -1]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "UINT64s" do
    let(:signature) { "t" }
    good = [
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :little, 0],
      ["\xff\xff\xff\xff\xff\xff\xff\x7f", :little, 9_223_372_036_854_775_807],
      ["\x00\x00\x00\x00\x00\x00\x00\x80", :little, 9_223_372_036_854_775_808],
      ["\xff\xff\xff\xff\xff\xff\xff\xff", :little, 18_446_744_073_709_551_615],
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :big, 0],
      ["\x7f\xff\xff\xff\xff\xff\xff\xff", :big, 9_223_372_036_854_775_807],
      ["\x80\x00\x00\x00\x00\x00\x00\x00", :big, 9_223_372_036_854_775_808],
      ["\xff\xff\xff\xff\xff\xff\xff\xff", :big, 18_446_744_073_709_551_615]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "DOUBLEs" do
    let(:signature) { "d" }
    # See https://en.wikipedia.org/wiki/Double-precision_floating-point_format
    # for binary representations
    # TODO: figure out IEEE754 comparisons
    good = [
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :little, 0.0],
      # But == cant distinguish -0.0
      ["\x00\x00\x00\x00\x00\x00\x00\x80", :little, -0.0],
      ["\x00\x00\x00\x00\x00\x00\x00\x40", :little, 2.0],
      # But NaN == NaN is false!
      # ["\xff\xff\xff\xff\xff\xff\xff\xff", :little, Float::NAN],
      ["\x00\x00\x00\x00\x00\x00\x00\x00", :big, 0.0],
      ["\x80\x00\x00\x00\x00\x00\x00\x00", :big, -0.0],
      ["\x40\x00\x00\x00\x00\x00\x00\x00", :big, 2.0]
      # ["\xff\xff\xff\xff\xff\xff\xff\xff", :big, Float::NAN]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end
end
