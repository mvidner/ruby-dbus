#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# Helper to access PacketUnmarshaller internals.
# Add it to its public API?
# @param pu [PacketUnmarshaller]
# @return [String] the binary string with unconsumed data
def remaining_buffer(p_u)
  buf = p_u.instance_variable_get(:@buffy)
  # This returns "" if idx is just past the end of the string,
  # and nil if it is further.
  buf[p_u.idx..-1]
end

RSpec.shared_examples "parses good data" do |cases|
  describe "parses all the instances of good test data" do
    cases.each_with_index do |(buffer, endianness, value), i|
      it "parses data ##{i}" do
        buffer = String.new(buffer, encoding: Encoding::BINARY)
        subject = described_class.new(buffer, endianness)

        # NOTE: it's [value], not value.
        # unmarshall works on multiple signatures but we use one
        expect(subject.unmarshall(signature)).to eq([value])

        expect(remaining_buffer(subject)).to be_empty
      end
    end
  end
end

RSpec.shared_examples "reports bad data" do |cases|
  describe "reports all the instances of bad test data" do
    cases.each_with_index do |(buffer, endianness, exc_class, msg_re), i|
      it "reports data ##{i}" do
        buffer = String.new(buffer, encoding: Encoding::BINARY)
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

  context "STRINGs" do
    let(:signature) { "s" }
    good = [
      ["\x00\x00\x00\x00\x00", :little, ""],
      ["\x02\x00\x00\x00\xC5\x98\x00", :little, "Ř"],
      ["\x03\x00\x00\x00\xEF\xBF\xBF\x00", :little, "\uffff"],
      ["\x00\x00\x00\x00\x00", :big, ""],
      ["\x00\x00\x00\x02\xC5\x98\x00", :big, "Ř"],
      ["\x00\x00\x00\x03\xEF\xBF\xBF\x00", :big, "\uffff"],
      # maximal UTF-8 codepoint U+10FFFF
      ["\x00\x00\x00\x04\xF4\x8F\xBF\xBF\x00", :big, "\u{10ffff}"]
    ]
    _bad_but_valid = [
      # NUL in the middle
      ["\x03\x00\x00\x00a\x00b\x00", :little, DBus::InvalidPacketException, /Invalid string/],
      # invalid UTF-8
      ["\x04\x00\x00\x00\xFF\xFF\xFF\xFF\x00", :little, DBus::InvalidPacketException, /Invalid string/],
      # overlong sequence encoding an "A"
      ["\x02\x00\x00\x00\xC1\x81\x00", :little, DBus::InvalidPacketException, /Invalid string/],
      # first codepoint outside UTF-8, U+110000
      ["\x04\x00\x00\x00\xF4\x90\xC0\xC0\x00", :little, DBus::InvalidPacketException, /Invalid string/]

    ]
    bad = [
      ["\x00\x00\x00\x00\x55", :little, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x01\x00\x00\x00@\x55", :little, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x00\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00", :little, DBus::IncompleteBufferException, /./]
    ]
    include_examples "parses good data", good
    include_examples "reports bad data", bad
    include_examples "reports empty data"
  end

  context "OBJECT_PATHs" do
    let(:signature) { "o" }
    long_path = "/#{"A" * 511}"
    good = [
      ["\x01\x00\x00\x00/\x00", :little, "/"],
      ["\x20\x00\x00\x00/99Numbers/_And_Underscores/anyw\x00", :little, "/99Numbers/_And_Underscores/anyw"],
      # no size limit like for other names
      ["\x00\x02\x00\x00#{long_path}\x00", :little, long_path],
      ["\x00\x00\x00\x01/\x00", :big, "/"],
      ["\x00\x00\x00\x20/99Numbers/_And_Underscores/anyw\x00", :big, "/99Numbers/_And_Underscores/anyw"]
    ]
    _bad_but_valid = [
      ["\x00\x00\x00\x00\x00", :little, DBus::InvalidPacketException, /Invalid object path/],
      ["\x00\x00\x00\x00\x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      ["\x00\x00\x00\x05/_//_\x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      ["\x00\x00\x00\x05/_/_/\x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      ["\x00\x00\x00\x05/_/_ \x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      ["\x00\x00\x00\x05/_/_-\x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      # NUL in the middle
      ["\x00\x00\x00\x05/_/_\x00\x00", :big, DBus::InvalidPacketException, /Invalid object path/],
      # accented a
      ["\x00\x00\x00\x05/_/\xC3\xA1\x00", :big, DBus::InvalidPacketException, /Invalid object path/]
    ]
    bad = [
      # string-like baddies
      ["\x00\x00\x00\x00\x55", :little, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x01\x00\x00\x00/\x55", :little, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x00\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00\x00", :little, DBus::IncompleteBufferException, /./],
      ["\x00", :little, DBus::IncompleteBufferException, /./]
    ]
    include_examples "parses good data", good
    include_examples "reports bad data", bad
    include_examples "reports empty data"
  end

  context "SIGNATUREs" do
    let(:signature) { "g" }
    good = [
      ["\x00\x00", :little, ""],
      ["\x00\x00", :big, ""],
      ["\x01b\x00", :little, "b"],
      ["\x01b\x00", :big, "b"]
    ]
    _bad_but_valid = [
      ["\x01!\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      ["\x01r\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      ["\x02ae\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      ["\x01a\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      # dict_entry with other than 2 members
      ["\x03a{}\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      ["\x04a{s}\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      ["\x06a{sss}\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      # dict_entry with non-basic key
      ["\x05a{vs}\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      # dict_entry outside array
      ["\x04{sv}\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      # dict_entry outside array
      ["\x07a({sv})\x00", :big, DBus::InvalidPacketException, /Invalid signature/],
      # NUL in the middle
      ["\x03a\x00y\x00", :big, DBus::InvalidPacketException, /Invalid signature/]
    ]
    bad = [
      # string-like baddies
      ["\x00\x55", :big, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x01b\x55", :big, DBus::InvalidPacketException, /not NUL-terminated/],
      ["\x00", :little, DBus::IncompleteBufferException, /./]
    ]
    include_examples "parses good data", good
    include_examples "reports bad data", bad
    include_examples "reports empty data"
  end

  context "ARRAYs" do
    # marshalling format:
    # - (alignment of data_bytes)
    # - UINT32 data_bytes (without any alignment padding)
    # - (alignment of ITEM_TYPE, even if the array is empty)
    # - ITEM_TYPE item1
    # - (alignment of ITEM_TYPE)
    # - ITEM_TYPE item2...
    context "of BYTEs" do
      # TODO: will want to special-case this
      # and represent them as binary strings
      let(:signature) { "ay" }

      # Here we repeat the STRINGs test data (without the trailing NUL)
      # but the outcomes are different
      good = [
        ["\x00\x00\x00\x00", :little, []],
        ["\x02\x00\x00\x00\xC5\x98", :little, [0xC5, 0x98]],
        ["\x03\x00\x00\x00\xEF\xBF\xBF", :little, [0xEF, 0xBF, 0xBF]],
        ["\x00\x00\x00\x00", :big, []],
        ["\x00\x00\x00\x02\xC5\x98", :big, [0xC5, 0x98]],
        ["\x00\x00\x00\x03\xEF\xBF\xBF", :big, [0xEF, 0xBF, 0xBF]],
        # maximal UTF-8 codepoint U+10FFFF
        ["\x00\x00\x00\x04\xF4\x8F\xBF\xBF", :big, [0xF4, 0x8F, 0xBF, 0xBF]],
        # NUL in the middle
        ["\x03\x00\x00\x00a\x00b", :little, [0x61, 0, 0x62]],
        # invalid UTF-8
        ["\x04\x00\x00\x00\xFF\xFF\xFF\xFF", :little, [0xFF, 0xFF, 0xFF, 0xFF]],
        # overlong sequence encoding an "A"
        ["\x02\x00\x00\x00\xC1\x81", :little, [0xC1, 0x81]],
        # first codepoint outside UTF-8, U+110000
        ["\x04\x00\x00\x00\xF4\x90\xC0\xC0", :little, [0xF4, 0x90, 0xC0, 0xC0]]
      ]
      bad = [
        # With basic types, by the time we have found the message to be invalid,
        # it is nevertheless well-formed and we could read the next message.
        # However, an overlong array (body longer than 64MiB) is a good enough
        # reason to drop the connection, which is what InvalidPacketException
        # does, right? Doesn't it?
        # Well it does, by crashing the entire process.
        # That should be made more graceful.

        ["\x01\x00\x00\x04", :little, DBus::InvalidPacketException, /ARRAY body longer than 64MiB/],

        ["\x02\x00\x00\x00\xAA", :little, DBus::IncompleteBufferException, /./],
        ["\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
        ["\x00\x00", :little, DBus::IncompleteBufferException, /./],
        ["\x00", :little, DBus::IncompleteBufferException, /./]
      ]
      include_examples "parses good data", good
      include_examples "reports bad data", bad
      include_examples "reports empty data"
    end

    context "of UINT64s" do
      let(:signature) { "at" }

      good = [
        [
          # body size, padding
          "\x00\x00\x00\x00" \
          "\x00\x00\x00\x00", :little, []
        ],
        [
          # body size, padding, item, item
          "\x10\x00\x00\x00" \
          "\x00\x00\x00\x00" \
          "\x01\x00\x00\x00\x00\x00\x00\x00" \
          "\x02\x00\x00\x00\x00\x00\x00\x00", :little, [1, 2]
        ]
      ]
      bad = [
        # missing padding
        ["\x00\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
        [
          # (zero) body size, non-zero padding, (no items)
          "\x00\x00\x00\x00" \
          "\xDE\xAD\xBE\xEF", :little, DBus::InvalidPacketException, /./
        ]
      ]
      include_examples "parses good data", good
      include_examples "reports bad data", bad
      include_examples "reports empty data"
    end

    # arrays let us demonstrate the padding of their elements
    context "of STRUCT of 2 UINT16s" do
      let(:signature) { "a(qq)" }

      good = [
        [
          # body size, padding
          "\x00\x00\x00\x00" \
          "\x00\x00\x00\x00", :little, []
        ],
        [
          # body size, padding, item, padding, item
          "\x0C\x00\x00\x00" \
          "\x00\x00\x00\x00" \
          "\x01\x00\x02\x00" \
          "\x00\x00\x00\x00" \
          "\x03\x00\x04\x00", :little, [[1, 2], [3, 4]]
        ],
        [
          # body size, padding, item, padding, item, padding, item
          "\x14\x00\x00\x00" \
          "\x00\x00\x00\x00" \
          "\x05\x00\x06\x00" \
          "\x00\x00\x00\x00" \
          "\x07\x00\x08\x00" \
          "\x00\x00\x00\x00" \
          "\x09\x00\x0A\x00", :little, [[5, 6], [7, 8], [9, 10]]
        ]
      ]
      bad = [
        # missing padding
        ["\x00\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
        [
          # (zero) body size, non-zero padding, (no items)
          "\x00\x00\x00\x00" \
          "\xDE\xAD\xBE\xEF", :little, DBus::InvalidPacketException, /./
        ]
      ]
      include_examples "parses good data", good
      include_examples "reports bad data", bad
      include_examples "reports empty data"
    end

    context "of DICT_ENTRIES" do
      let(:signature) { "a{yq}" }

      good = [
        [
          # body size, padding
          "\x00\x00\x00\x00" \
          "\x00\x00\x00\x00", :little, {}
        ],
        [
          # 4 body size,
          # 4 (dict_entry) padding,
          # 1 key, 1 padding, 2 value
          # 4 (dict_entry) padding,
          # 1 key, 1 padding, 2 value
          "\x0C\x00\x00\x00" \
          "\x00\x00\x00\x00" \
          "\x01\x00\x02\x00" \
          "\x00\x00\x00\x00" \
          "\x03\x00\x04\x00", :little, { 1 => 2, 3 => 4 }
        ],
        [
          # 4 body size,
          # 4 (dict_entry) padding,
          # 1 key, 1 padding, 2 value
          # 4 (dict_entry) padding,
          # 1 key, 1 padding, 2 value
          "\x00\x00\x00\x0C" \
          "\x00\x00\x00\x00" \
          "\x01\x00\x00\x02" \
          "\x00\x00\x00\x00" \
          "\x03\x00\x00\x04", :big, { 1 => 2, 3 => 4 }
        ]
      ]
      bad = [
        # missing padding
        ["\x00\x00\x00\x00", :little, DBus::IncompleteBufferException, /./],
        [
          # (zero) body size, non-zero padding, (no items)
          "\x00\x00\x00\x00" \
          "\xDE\xAD\xBE\xEF", :little, DBus::InvalidPacketException, /./
        ]
      ]
      include_examples "parses good data", good
      include_examples "reports bad data", bad
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

      good = [
        ["\x01\x00\x02\x00", :little, [1, 2]],
        ["\x00\x03\x00\x04", :big, [3, 4]]
      ]
      include_examples "parses good data", good
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

    good = [
      ["\x01y\x00\xFF", :little, 255],
      [
        # signature, padding, value
        "\x01u\x00" \
        "\x00" \
        "\x01\x00\x00\x00", :little, 1
      ],
      # nested variant
      [
        "\x01v\x00" \
        "\x01y\x00\xFF", :little, 255
      ]
    ]
    _bad_but_valid = [
      # variant nested too deep
      [
        "#{"\x01v\x00" * 70}" \
        "\x01y\x00\xFF", :little, DBus::InvalidPacketException, /nested too deep/
      ]
    ]
    bad = [
      # IDEA: test other libraries by sending them an empty variant?
      # the signature has no type
      ["\x00\x00", :little, DBus::InvalidPacketException, /1 value, 0 found/],
      # the signature has more than one type
      ["\x02yy\x00\xFF\xFF", :little, DBus::InvalidPacketException, /1 value, 2 found/]
    ]
    include_examples "parses good data", good
    include_examples "reports bad data", bad
    include_examples "reports empty data"
  end
end
