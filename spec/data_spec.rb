#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# The from_raw methods are tested in packet_unmarshaller_spec.rb

RSpec.shared_examples "#== and #eql? work for basic types" do |*args|
  plain_a = args.fetch(0, 22)
  plain_b = args.fetch(1, 222)

  describe "#eql?" do
    it "returns true for same class and value" do
      a = described_class.new(plain_a)
      b = described_class.new(plain_a)
      expect(a).to eql(b)
    end

    it "returns false for same class, different value" do
      a = described_class.new(plain_a)
      b = described_class.new(plain_b)
      expect(a).to_not eql(b)
    end

    it "returns false for same value but plain class" do
      a = described_class.new(plain_a)
      b = plain_a
      expect(a).to_not eql(b)
    end
  end

  describe "#==" do
    it "returns true for same class and value" do
      a = described_class.new(plain_a)
      b = described_class.new(plain_a)
      expect(a).to eq(b)
    end

    it "returns false for same class, different value" do
      a = described_class.new(plain_a)
      b = described_class.new(plain_b)
      expect(a).to_not eq(b)
    end

    it "returns true for same value but plain class" do
      a = described_class.new(plain_a)
      b = plain_a
      expect(a).to eq(b)
    end
  end
end

RSpec.shared_examples "constructor accepts numeric range" do |min, max|
  describe "#initialize" do
    it "accepts the min value #{min}" do
      expect(described_class.new(min).value).to eql(min)
    end

    it "accepts the max value #{max}" do
      expect(described_class.new(max).value).to eql(max)
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

RSpec.shared_examples "constructor accepts plain or typed values" do |plain_list|
  describe "#initialize" do
    Array(plain_list).each do |plain|
      it "accepts the plain value #{plain.inspect}" do
        expect(described_class.new(plain).value).to eql(plain)
      end

      it "accepts the typed value #{plain.inspect}" do
        typed = described_class.new(plain)
        expect(described_class.new(typed).value).to eql(plain)
      end
    end
  end
end

# FIXME: decide eq and eql here
RSpec.shared_examples "constructor (kwargs) accepts values" do |list|
  describe "#initialize" do
    list.each do |value, kwargs_hash|
      it "accepts the plain value #{value.inspect}, #{kwargs_hash.inspect}" do
        expect(described_class.new(value, **kwargs_hash).value).to eq(value)
      end

      it "accepts the typed value #{value.inspect}, #{kwargs_hash.inspect}" do
        typed = described_class.new(value, **kwargs_hash)
        expect(described_class.new(typed, **kwargs_hash).value).to eq(value)
      end
    end
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

RSpec.shared_examples "constructor (kwargs) rejects values" do |bad_list|
  describe "#initialize" do
    bad_list.each do |(value, kwargs_hash, exc_class, msg_substr)|
      it "rejects #{value.inspect}, #{kwargs_hash.inspect} with #{exc_class}: #{msg_substr}" do
        msg_re = Regexp.new(Regexp.quote(msg_substr))
        expect { described_class.new(value, **kwargs_hash) }.to raise_error(exc_class, msg_re)
      end
    end
  end
end

# TODO: Look at conversions? to_str, to_int?

describe DBus::Data do
  T = DBus::Type unless const_defined? "T"

  # test initialization, from user code, or from packet (from_raw)
  # remember to unpack if initializing from Data::Base
  # #value should recurse inside so that the user doesnt have to
  # Kick InvalidPacketException out of here?

  describe DBus::Data::Byte do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", 0, 2**8 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::Int16 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", -2**15, 2**15 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::UInt16 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", 0, 2**16 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::Int32 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", -2**31, 2**31 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::UInt32 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", 0, 2**32 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::Int64 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", -2**63, 2**63 - 1
    include_examples "constructor accepts plain or typed values", 42
  end

  describe DBus::Data::UInt64 do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts numeric range", 0, 2**64 - 1
    include_examples "constructor accepts plain or typed values", 42
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

    include_examples "#== and #eql? work for basic types", false, true
    include_examples "constructor accepts plain or typed values", false
  end

  describe DBus::Data::Double do
    include_examples "#== and #eql? work for basic types"
    include_examples "constructor accepts plain or typed values", Math::PI

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
        # FIXME: InvalidPacketException is wrong here, it should be ArgumentError
        ["a\x00b", DBus::InvalidPacketException, "contains NUL"],
        # invalid UTF-8
        ["\xFF\xFF\xFF\xFF", DBus::InvalidPacketException, "not in UTF-8"],
        # overlong sequence encoding an "A"
        ["\xC1\x81", DBus::InvalidPacketException, "not in UTF-8"],
        # first codepoint outside UTF-8, U+110000
        ["\xF4\x90\xC0\xC0", DBus::InvalidPacketException, "not in UTF-8"]
      ]

      include_examples "#== and #eql? work for basic types", "foo", "bar"
      include_examples "constructor accepts plain or typed values", good
      include_examples "constructor rejects values from this list", bad

      describe ".alignment" do
        # this overly specific test avoids a redundant alignment call
        # in the production code
        it "returns the correct value" do
          expect(described_class.alignment).to eq 4
        end
      end
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

      include_examples "#== and #eql? work for basic types", "/foo", "/bar"
      include_examples "constructor accepts plain or typed values", good
      include_examples "constructor rejects values from this list", bad

      describe ".alignment" do
        # this overly specific test avoids a redundant alignment call
        # in the production code
        it "returns the correct value" do
          expect(described_class.alignment).to eq 4
        end
      end
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

      include_examples "#== and #eql? work for basic types", "aah", "aaaaah"
      include_examples "constructor accepts plain or typed values", good
      include_examples "constructor rejects values from this list", bad

      describe ".alignment" do
        # this overly specific test avoids a redundant alignment call
        # in the production code
        it "returns the correct value" do
          expect(described_class.alignment).to eq 1
        end
      end
    end
  end

  describe "containers" do
    describe DBus::Data::Array do
      good = [
        # [[1, 2, 3], type: nil],
        [[1, 2, 3], { type: "aq" }],
        [[1, 2, 3], { type: T::Array[T::UINT16] }],
        [[1, 2, 3], { type: T::Array["q"] }],
        [[DBus::Data::UInt16.new(1), DBus::Data::UInt16.new(2), DBus::Data::UInt16.new(3)], { type: T::Array["q"] }]
        # TODO: others
      ]

      bad = [
        # undesirable type guessing
        ## [[1, 2, 3], { type: nil }, DBus::InvalidPacketException, "Unknown type code"],
        ## [[1, 2, 3], { type: "!" }, DBus::InvalidPacketException, "Unknown type code"]
        # TODO: others
      ]

      include_examples "constructor (kwargs) accepts values", good
      include_examples "constructor (kwargs) rejects values", bad

      describe ".from_typed" do
        it "creates new instance from given object and type" do
          type = T::Array[String]
          expect(described_class.from_typed(["test", "lest"], type: type)).to be_a(described_class)
        end
      end
    end

    describe DBus::Data::Struct do
      three_words = ::Struct.new(:a, :b, :c)

      qqq = T::Struct[T::UINT16, T::UINT16, T::UINT16]
      integers = [1, 2, 3]
      uints = [DBus::Data::UInt16.new(1), DBus::Data::UInt16.new(2), DBus::Data::UInt16.new(3)]

      # TODO: all the reasonable initialization params
      # need to be normalized into one/few internal representation.
      # So check what is the result
      #
      # Internally, it must be Data::Base
      # Perhaps distinguish #value => Data::Base
      # and #plain_value => plain Ruby
      #
      # but then, can they mutate?
      #
      # TODO: also check data ownership: reasonable to own the data?
      # can make it explicit?
      good = [
        # from plain array; various *type* styles
        [integers, { type: DBus.type("(qqq)") }],
        [integers, { type: T::Struct["q", "q", "q"] }],
        [integers, { type: T::Struct[T::UINT16, T::UINT16, T::UINT16] }],
        [integers, { type: T::Struct[*DBus.types("qqq")] }],
        # plain array of data
        [uints, { type: qqq }],
        # ::Struct
        [three_words.new(*integers), { type: qqq }],
        [three_words.new(*uints), { type: qqq }]
        # TODO: others
      ]

      # check these only when canonicalizing @value, because that will
      # type-check the value deeply
      _bad_but_valid = [
        # STRUCT specific: member count mismatch
        [[1, 2], { type: qqq }, ArgumentError, "???"],
        [[1, 2, 3, 4], { type: qqq }, ArgumentError, "???"]
        # TODO: others
      ]

      include_examples "constructor (kwargs) accepts values", good
      # include_examples "constructor (kwargs) rejects values", bad

      describe ".from_typed" do
        it "creates new instance from given object and type" do
          type = T::Struct[T::STRING, T::STRING]
          expect(described_class.from_typed(["test", "lest"].freeze, type: type))
            .to be_a(described_class)
        end
      end
    end

    describe DBus::Data::Variant do
      describe ".from_typed" do
        it "creates new instance from given object and type" do
          type = DBus.type(T::VARIANT)
          value = described_class.from_typed("test", type: type)
          expect(value).to be_a(described_class)
          expect(value.type.to_s).to eq "v"
          expect(value.member_type.to_s).to eq "s"
        end
      end
    end

    describe DBus::Data::DictEntry do
    end
  end
end
