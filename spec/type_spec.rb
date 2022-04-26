#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus do
  describe ".type" do
    good = [
      "i",
      "ai",
      "a(ii)",
      "aai"
    ]

    context "valid single types" do
      good.each do |s|
        it "#{s.inspect} is parsed" do
          expect(DBus.type(s).to_s).to eq(s)
        end
      end
    end

    bad = [
      ["\x00", "Unknown type code"],
      ["!", "Unknown type code"],

      # ARRAY related
      ["a", "Empty ARRAY"],
      ["aa", "Empty ARRAY"],

      # STRUCT related
      ["r", "Abstract STRUCT"],
      ["()", "Empty STRUCT"],
      ["(ii", "STRUCT not closed"],
      ["a{i)", "STRUCT unexpectedly closed"],

      # TODO: deep nesting arrays, structs, combined

      # DICT_ENTRY related
      ["e", "Abstract DICT_ENTRY"],
      ["a{}", "DICT_ENTRY must have 2 subtypes, found 0"],
      ["a{s}", "DICT_ENTRY must have 2 subtypes, found 1"],
      ["a{sss}", "DICT_ENTRY must have 2 subtypes, found 3"],
      ["a{vs}", "DICT_ENTRY key must be basic (non-container)"],
      ["{sv}", "DICT_ENTRY not an immediate child of an ARRAY"],
      ["a({sv})", "DICT_ENTRY not an immediate child of an ARRAY"],
      ["a{sv", "DICT_ENTRY not closed"],
      ["}", "DICT_ENTRY unexpectedly closed"],

      # Too long
      ["(#{"y" * 254})", "longer than 255"],

      # not Single Complete Types
      ["", "expecting a Single Complete Type"],
      ["ii", "more than a Single Complete Type"]
    ]
    context "invalid single types" do
      bad.each.each do |s, msg|
        it "#{s.inspect} raises an exception mentioning: #{msg}" do
          rx = Regexp.new(Regexp.quote(msg))
          expect { DBus.type(s) }.to raise_error(DBus::Type::SignatureException, rx)
        end
      end
    end
  end

  describe ".types" do
    good = [
      "",
      "ii"
    ]

    context "valid signatures" do
      good.each do |s|
        it "#{s.inspect} is parsed" do
          expect(DBus.types(s).map(&:to_s).join).to eq(s)
        end
      end
    end
  end

  describe DBus::Type do
    describe "#<<" do
      it "raises if the argument is not a Type" do
        t = DBus::Type.new(DBus::Type::ARRAY)
        expect { t << "s" }.to raise_error(ArgumentError)
      end
    end

    describe DBus::Type::Array do
      describe ".[]" do
        it "takes Type argument" do
          t = DBus::Type::Array[DBus::Type.new("s")]
          expect(t.to_s).to eq "as"
        end

        it "takes 's':String argument" do
          t = DBus::Type::Array["s"]
          expect(t.to_s).to eq "as"
        end

        it "takes String:Class argument" do
          t = DBus::Type::Array[String]
          expect(t.to_s).to eq "as"
        end
      end
    end

    describe DBus::Type::Hash do
      describe ".[]" do
        it "takes Type arguments" do
          t = DBus::Type::Hash[DBus::Type.new("s"), DBus::Type.new("v")]
          expect(t.to_s).to eq "a{sv}"
        end

        it "takes 's':String arguments" do
          t = DBus::Type::Hash["s", "v"]
          expect(t.to_s).to eq "a{sv}"
        end

        it "takes String:Class argument" do
          t = DBus::Type::Hash[String, DBus::Type::VARIANT]
          expect(t.to_s).to eq "a{sv}"
        end
      end
    end

    describe DBus::Type::Struct do
      describe ".[]" do
        it "takes Type arguments" do
          t = DBus::Type::Struct[DBus::Type.new("s"), DBus::Type.new("v")]
          expect(t.to_s).to eq "(sv)"
        end

        it "takes 's':String arguments" do
          t = DBus::Type::Struct["s", "v"]
          expect(t.to_s).to eq "(sv)"
        end

        it "takes String:Class argument" do
          t = DBus::Type::Struct[String, DBus::Type::VARIANT]
          expect(t.to_s).to eq "(sv)"
        end
      end
    end
  end
end
