#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"
require "ostruct"
require "yaml"

data_dir = File.expand_path("data", __dir__)
marshall_yaml_s = File.read("#{data_dir}/marshall.yaml")
marshall_yaml = YAML.safe_load(marshall_yaml_s)

# Helper to access PacketUnmarshaller internals.
# Add it to its public API?
# @param p_u [PacketUnmarshaller]
# @return [String] the binary string with unconsumed data
def remaining_buffer(p_u)
  raw_msg = p_u.instance_variable_get(:@raw_msg)
  raw_msg.remaining_bytes
end

RSpec.shared_examples "parses good data" do |cases|
  describe "parses all the instances of good test data" do
    cases.each_with_index do |(buffer, endianness, expected), i|
      it "parses plain data ##{i}" do
        buffer = String.new(buffer, encoding: Encoding::BINARY)
        subject = described_class.new(buffer, endianness)

        results = subject.unmarshall(signature, mode: :plain)
        # unmarshall works on multiple signatures but we use one
        expect(results).to be_an(Array)
        expect(results.size).to eq(1)
        result = results.first

        expect(result).to eq(expected)

        expect(remaining_buffer(subject)).to be_empty
      end

      it "parses exact data ##{i}" do
        buffer = String.new(buffer, encoding: Encoding::BINARY)
        subject = described_class.new(buffer, endianness)

        results = subject.unmarshall(signature, mode: :exact)
        # unmarshall works on multiple signatures but we use one
        expect(results).to be_an(Array)
        expect(results.size).to eq(1)
        result = results.first

        expect(result).to be_a(DBus::Data::Base)
        expect(result.value).to eq(expected)

        expect(remaining_buffer(subject)).to be_empty
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
  context "marshall.yaml" do
    marshall_yaml.each do |test|
      t = OpenStruct.new(test)
      signature = t.sig
      buffer = buffer_from_yaml(t.buf)
      endianness = t.end.to_sym

      # successful parse
      if !t.val.nil?
        expected = t.val

        it "parses a '#{signature}' to get #{t.val.inspect} (plain)" do
          subject = described_class.new(buffer, endianness)
          results = subject.unmarshall(signature, mode: :plain)
          # unmarshall works on multiple signatures but we use one
          expect(results).to be_an(Array)
          expect(results.size).to eq(1)
          result = results.first

          expect(result).to eq(expected)
          expect(remaining_buffer(subject)).to be_empty
        end

        it "parses a '#{t.sig}' to get #{t.val.inspect} (exact)" do
          subject = described_class.new(buffer, endianness)
          results = subject.unmarshall(signature, mode: :exact)
          # unmarshall works on multiple signatures but we use one
          expect(results).to be_an(Array)
          expect(results.size).to eq(1)
          result = results.first

          expect(result).to be_a(DBus::Data::Base)
          expect(result.value).to eq(expected)

          expect(remaining_buffer(subject)).to be_empty
        end
      elsif t.exc
        next if t.unmarshall == false

        exc_class = DBus.const_get(t.exc)
        msg_re = Regexp.new(Regexp.escape(t.msg))

        # TODO: InvalidPacketException is never rescued.
        # The other end is sending invalid data. Can we do better than crashing?
        # When we can test with peer connections, try it out.
        it "parses a '#{signature}' to report a #{t.exc}" do
          subject = described_class.new(buffer, endianness)
          expect { subject.unmarshall(signature, mode: :plain) }.to raise_error(exc_class, msg_re)

          subject = described_class.new(buffer, endianness)
          expect { subject.unmarshall(signature, mode: :exact) }.to raise_error(exc_class, msg_re)
        end
      end
    end
  end

  context "BYTEs" do
    let(:signature) { "y" }
    include_examples "reports empty data"
  end

  context "BOOLEANs" do
    let(:signature) { "b" }
    include_examples "reports empty data"
  end

  context "INT16s" do
    let(:signature) { "n" }
    include_examples "reports empty data"
  end

  context "UINT16s" do
    let(:signature) { "q" }
    include_examples "reports empty data"
  end

  context "INT32s" do
    let(:signature) { "i" }
    include_examples "reports empty data"
  end

  context "UINT32s" do
    let(:signature) { "u" }
    include_examples "reports empty data"
  end

  context "UNIX_FDs" do
    let(:signature) { "h" }
    include_examples "reports empty data"
  end

  context "INT64s" do
    let(:signature) { "x" }
    include_examples "reports empty data"
  end

  context "UINT64s" do
    let(:signature) { "t" }
    include_examples "reports empty data"
  end

  context "DOUBLEs" do
    let(:signature) { "d" }
    # See https://en.wikipedia.org/wiki/Double-precision_floating-point_format
    # for binary representations
    # TODO: figure out IEEE754 comparisons
    good = [
      # But == cant distinguish -0.0
      ["\x00\x00\x00\x00\x00\x00\x00\x80", :little, -0.0],
      # But NaN == NaN is false!
      # ["\xff\xff\xff\xff\xff\xff\xff\xff", :little, Float::NAN],
      ["\x80\x00\x00\x00\x00\x00\x00\x00", :big, -0.0]
      # ["\xff\xff\xff\xff\xff\xff\xff\xff", :big, Float::NAN]
    ]
    include_examples "parses good data", good
    include_examples "reports empty data"
  end

  context "STRINGs" do
    let(:signature) { "s" }
    include_examples "reports empty data"
  end

  context "OBJECT_PATHs" do
    let(:signature) { "o" }
    include_examples "reports empty data"
  end

  context "SIGNATUREs" do
    let(:signature) { "g" }
    include_examples "reports empty data"
  end

  context "ARRAYs" do
    context "of BYTEs" do
      let(:signature) { "ay" }
      include_examples "reports empty data"
    end

    context "of UINT64s" do
      let(:signature) { "at" }
      include_examples "reports empty data"
    end

    context "of STRUCT of 2 UINT16s" do
      let(:signature) { "a(qq)" }
      include_examples "reports empty data"
    end

    context "of DICT_ENTRIES" do
      let(:signature) { "a{yq}" }
      include_examples "reports empty data"
    end
  end

  context "STRUCTs" do
    # TODO: this is invalid but does not raise
    context "(generic 'r' struct)" do
      let(:signature) { "r" }
    end

    context "of two shorts" do
      let(:signature) { "(qq)" }
      include_examples "reports empty data"
    end
  end

  # makes sense here? or in array? remember invalid sigs are rejected elsewhere
  context "DICT_ENTRYs" do
    context "(generic 'e' dict_entry)" do
      let(:signature) { "e" }
    end
  end

  context "VARIANTs" do
    let(:signature) { "v" }
    include_examples "reports empty data"
  end
end
