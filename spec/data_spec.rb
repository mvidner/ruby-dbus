#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# The from_raw methods are tested in packet_unmarshaller_spec.rb

RSpec.shared_examples "constructor accepts numeric range" do |min, max|
  describe "#initialize" do
    it "accepts the min value #{min}" do
      expect(described_class.new(min).value).to eq(min)
    end

    it "accepts the max value #{max}" do
      expect(described_class.new(max).value).to eq(max)
    end

    it "raises on too small a value #{min - 1}" do
      expect { described_class.new(min - 1) }.to raise_error(RangeError)
    end

    it "raises on too big a value #{max + 1}" do
      expect { described_class.new(max + 1) }.to raise_error(RangeError)
    end

    it "raises on nil" do
      expect { described_class.new(nil) }.to raise_error(RangeError)
    end
  end
end

RSpec.shared_examples "constructor accepts plain or typed value" do |plain|
  describe "#initialize" do
    it "accepts the plain value #{plain.inspect}" do
      expect(described_class.new(plain).value).to eq(plain)
    end

    it "accepts the typed value #{plain.inspect}" do
      typed = described_class.new(plain)
      expect(described_class.new(typed).value).to eq(plain)
    end
  end
end

RSpec.shared_examples "constructor accepts plain or typed values from this list" do |plain_list|
  plain_list.each do |plain|
    include_examples "constructor accepts plain or typed value", plain
  end
end

RSpec.shared_examples "constructor rejects values from this list" do |bad_list|
  describe "#initialize" do
    bad_list.each do |(value, exc_class, msg_substr)|
      it "rejects #{value.inspect} with #{exc_class}: #{msg_substr}" do
        msg_re = Regexp.new(Regexp.quote(msg_substr))
        expect { described_class.new(value) }.to raise_error(exc_class, msg_re)
      end
    end
  end
end

# FIXME: copy constructors should work: Data::Base.new(other_data_base) should take its value,
# also one exception where Boolean would look inside to produce false
# Look at conversions? to_str, to_int?

describe DBus::Data do
  # test initialization, from user code, or from packet (from_raw)
  # remember to unpack if initializing from Data::Base
  # #value should recurse inside so that the user doesnt have to
  # Kick InvalidPacketException out of here?

  describe DBus::Data::Byte do
    include_examples "constructor accepts numeric range", 0, 2**8 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::Int16 do
    include_examples "constructor accepts numeric range", -2**15, 2**15 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::UInt16 do
    include_examples "constructor accepts numeric range", 0, 2**16 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::Int32 do
    include_examples "constructor accepts numeric range", -2**31, 2**31 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::UInt32 do
    include_examples "constructor accepts numeric range", 0, 2**32 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::Int64 do
    include_examples "constructor accepts numeric range", -2**63, 2**63 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::UInt64 do
    include_examples "constructor accepts numeric range", 0, 2**64 - 1
    include_examples "constructor accepts plain or typed value", 42
  end

  describe DBus::Data::Boolean do
    describe "#initialize" do
      it "accepts false and true" do
        expect(described_class.new(false).value).to eq(false)
        expect(described_class.new(true).value).to eq(true)
      end

      it "accepts truth value of other objects" do
        expect(described_class.new(nil).value).to eq(false)
        expect(described_class.new(0).value).to eq(true) # !
        expect(described_class.new(1).value).to eq(true)
        expect(described_class.new(Time.now).value).to eq(true)
      end
    end

    include_examples "constructor accepts plain or typed value", false
  end

  describe DBus::Data::Double do
    include_examples "constructor accepts plain or typed value", Math::PI

    describe "#initialize" do
      it "raises on values that can't be made a Float" do
        expect { described_class.new(nil) }.to raise_error(TypeError)
        expect { described_class.new("one") }.to raise_error(ArgumentError)
        expect { described_class.new(/itsaregexp/) }.to raise_error(TypeError)
      end
    end
  end

  describe "basic, string-like types" do
    describe DBus::Data::String do
      # TODO: what about strings with good codepoints but encoded in
      # let's say Encoding::ISO8859_2?
      good = [
        "",
        "Ř",
        # a Noncharacter, but well-formed Unicode
        # https://www.unicode.org/versions/corrigendum9.html
        "\uffff",
        # maximal UTF-8 codepoint U+10FFFF
        "\u{10ffff}"
      ]

      bad = [
        # NUL in the middle
        ["a\x00b", DBus::InvalidPacketException, "contains NUL"],
        # invalid UTF-8
        ["\xFF\xFF\xFF\xFF", DBus::InvalidPacketException, "not in UTF-8"],
        # overlong sequence encoding an "A"
        ["\xC1\x81", DBus::InvalidPacketException, "not in UTF-8"],
        # first codepoint outside UTF-8, U+110000
        ["\xF4\x90\xC0\xC0", DBus::InvalidPacketException, "not in UTF-8"]
      ]

      include_examples "constructor accepts plain or typed values from this list", good
      include_examples "constructor rejects values from this list", bad
    end

    describe DBus::Data::ObjectPath do
      good = [
        "/"
        # TODO: others
      ]

      bad = [
        ["", DBus::InvalidPacketException, "Invalid object path"]
        # TODO: others
      ]

      include_examples "constructor accepts plain or typed values from this list", good
      include_examples "constructor rejects values from this list", bad
    end

    describe DBus::Data::Signature do
      good = [
        "",
        "i",
        "ii"
        # TODO: others
      ]

      bad = [
        ["!", DBus::InvalidPacketException, "Unknown type code"]
        # TODO: others
      ]

      include_examples "constructor accepts plain or typed values from this list", good
      include_examples "constructor rejects values from this list", bad
    end
  end

  describe "containers" do
    describe DBus::Data::Array do
    end

    describe DBus::Data::Struct do
    end

    describe DBus::Data::Variant do
    end

    describe DBus::Data::DictEntry do
    end
  end
end
