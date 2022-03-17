# frozen_string_literal: true

module DBus
  # better Type

  # basic vs container
  # basic is fixed or string-like
  module Data
    # The base class for explicitly typed values.
    #
    # A value is either {Basic} or a {Container}.
    # {Basic} values are either {Fixed}-size or {StringLike}.
    class Base
      # value: from raw_message
      # def initialize

      attr_reader :value

      def initialize(value)
        @value = value
      end

      def ==(other)
        @value == if other.is_a?(Base)
                    other.value
                  else
                    other
                  end
      end

      # Hash key equality
      # See https://ruby-doc.org/core-3.0.0/Object.html#method-i-eql-3F
      alias eql? ==
    end

    # A value that is not a {Container}.
    class Basic < Base
      def self.basic?
        true
      end
    end

    # A value that has a fixed size (unlike {StringLike}).
    class Fixed < Basic
      def self.fixed?
        true
      end

      # most Fixed types are valid
      # whatever bits from the wire are used to initialize them
      # @param mode [:plain,:exact]
      def self.from_raw(value, mode:)
        return value if mode == :plain

        new(value)
      end
    end

    # {DBus::Data::String}, {DBus::Data::ObjectPath}, or {DBus::Data::Signature}.
    class StringLike < Basic
      def self.fixed?
        false
      end
    end

    # Contains one or more other values.
    class Container < Base
      def self.basic?
        false
      end

      def self.fixed?
        false
      end
    end

    # Format strings for String#unpack, both little- and big-endian.
    Format = ::Struct.new(:little, :big)

    # Byte.
    # TODO: ByteArray
    class Byte < Fixed
      def self.type_code
        "y"
      end

      def self.alignment
        1
      end
      FORMAT = Format.new("C", "C")
      def self.format
        FORMAT
      end
    end

    # Boolean: encoded as a {UInt32} but only 0 and 1 are valid.
    class Boolean < Fixed
      def self.type_code
        "b"
      end

      def self.alignment
        4
      end
      FORMAT = Format.new("L<", "L>")
      def self.format
        FORMAT
      end

      def self.validate_raw!(value)
        return if [0, 1].member?(value)

        raise InvalidPacketException, "BOOLEAN must be 0 or 1, found #{value}"
      end

      def self.from_raw(value, mode:)
        validate_raw!(value)

        value = value == 1
        return value if mode == :plain

        new(value)
      end
    end

    # Signed 16 bit integer.
    class Int16 < Fixed
      def self.type_code
        "n"
      end

      def self.alignment
        2
      end
      FORMAT = Format.new("s<", "s>")
      def self.format
        FORMAT
      end
    end

    # Unsigned 16 bit integer.
    class UInt16 < Fixed
      def self.type_code
        "q"
      end

      def self.alignment
        2
      end
      FORMAT = Format.new("S<", "S>")
      def self.format
        FORMAT
      end
    end

    # Signed 32 bit integer.
    class Int32 < Fixed
      def self.type_code
        "i"
      end

      def self.alignment
        4
      end
      FORMAT = Format.new("l<", "l>")
      def self.format
        FORMAT
      end
    end

    # Unsigned 32 bit integer.
    class UInt32 < Fixed
      def self.type_code
        "u"
      end

      def self.alignment
        4
      end
      FORMAT = Format.new("L<", "L>")
      def self.format
        FORMAT
      end
    end

    # Signed 64 bit integer.
    class Int64 < Fixed
      def self.type_code
        "x"
      end

      def self.alignment
        8
      end
      FORMAT = Format.new("q<", "q>")
      def self.format
        FORMAT
      end
    end

    # Unsigned 64 bit integer.
    class UInt64 < Fixed
      def self.type_code
        "t"
      end

      def self.alignment
        8
      end
      FORMAT = Format.new("Q<", "Q>")
      def self.format
        FORMAT
      end
    end

    # Double-precision floating point number.
    class Double < Fixed
      def self.type_code
        "d"
      end

      def self.alignment
        8
      end
      FORMAT = Format.new("E", "G")
      def self.format
        FORMAT
      end
    end

    # UTF-8 encoded string.
    class String < StringLike
      def self.type_code
        "s"
      end

      def self.alignment
        4
      end

      def self.size_class
        UInt32
      end

      def self.validate_raw!(value)
        value.each_codepoint do |cp|
          raise InvalidPacketException, "Invalid string, contains NUL" if cp.zero?
        end
      rescue ArgumentError
        raise InvalidPacketException, "Invalid string, not in UTF-8"
      end

      def self.from_raw(value, mode:)
        value.force_encoding(Encoding::UTF_8)
        validate_raw!(value)
        return value if mode == :plain

        new(value)
      end
    end

    # See also {DBus::ObjectPath}
    class ObjectPath < StringLike
      def self.type_code
        "o"
      end

      def self.alignment
        4
      end

      def self.size_class
        UInt32
      end

      def self.from_raw(value, mode:)
        value = DBus::ObjectPath.new(value)
        return value if mode == :plain

        new(value)
      rescue DBus::Error => e
        raise InvalidPacketException, e.message
      end
    end

    # Signature string, zero or more single complete types.
    # See also {DBus::Type::Type}
    class Signature < StringLike
      def self.type_code
        "g"
      end

      def self.alignment
        1
      end

      def self.size_class
        Byte
      end

      def self.from_raw(value, mode:)
        # TODO: validate what got sent
        return value if mode == :plain

        new(value)
      end
    end

    # An Array, or a Dictionary (Hash).
    class Array < Container
      def self.type_code
        "a"
      end

      def self.alignment
        4
      end

      # TODO: check that Hash keys are basic types
      def self.from_items(value, mode:, hash: false)
        value = Hash[value] if hash
        return value if mode == :plain

        new(value)
      end
    end

    # A fixed size, heterogenerous tuple.
    class Struct < Container
      def self.type_code
        "r"
      end

      def self.alignment
        8
      end

      # @param value [::Array]
      def self.from_items(value, mode:)
        value.freeze
        return value if mode == :plain

        new(value)
      end
    end

    # A generic type
    class Variant < Container
      def self.type_code
        "v"
      end

      def self.alignment
        1
      end

      def self.from_items(value, mode:)
        return value if mode == :plain

        new(value)
      end
    end

    # Dictionary/Hash entry.
    # TODO: shouldn't instantiate?
    class DictEntry < Container
      def self.type_code
        "e"
      end

      def self.alignment
        8
      end

      # @param value [::Array]
      def self.from_items(value, mode:) # rubocop:disable Lint/UnusedMethodArgument
        value.freeze
        # DictEntry ignores the :exact mode
        value
      end
    end

    # Unix file descriptor, not implemented yet.
    class UnixFD < Fixed
      def self.type_code
        "h"
      end

      def self.alignment
        4
      end
      FORMAT = Format.new("L<", "L>")
      def self.format
        FORMAT
      end
    end

    consts = constants.map { |c_sym| const_get(c_sym) }
    classes = consts.find_all { |c| c.respond_to?(:type_code) }
    by_type_code = classes.map { |cl| [cl.type_code, cl] }.to_h

    # { "b" => Data::Boolean, "s" => Data::String, ...}
    BY_TYPE_CODE = by_type_code
  end
end
