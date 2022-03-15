module DBus

  class RawMessage
    # @return [String]
    #attr_reader :bytes

    # @return [Integer] position in the byte buffer
    attr_reader :pos

    # @return [:little,:big]
    attr_reader :endianness

    # @param bytes [String]
    # @param endianness [:little,:big,nil]
    #    if not given, read the 1st byte of *bytes*
    def initialize(bytes, endianness = nil)
      @bytes = bytes
      @pos = 0
      @endianness = endianness || self.class.endianness(@bytes[0])
    end

    # Get the endiannes switch as a Symbol,
    # which will make using it slightly more efficient
    # @param tag_char [String]
    # @return [:little,:big]
    def self.endianness(tag_char)
      case tag_char
      when LIL_END
        :little
      when BIG_END
        :big
      else
        raise InvalidPacketException, "Incorrect endianness #{tag_char.inspect}"
      end
    end

    # @return [String]
    # TODO: stress test this with encodings. always binary?
    def read(size)
      raise IncompleteBufferException if @pos + size > @bytes.bytesize
      ret = @bytes.slice(@pos, size)
      @pos += size      
      ret
    end

    # Align the *pos* index on a multiple of *alignment*
    # @param alignment [Integer] must be 1, 2, 4 or 8
    # @return [void]
    def align(alignment)
      case alignment
      when 1
        nil
      when 2, 4, 8
        bits = alignment - 1
        pad_size = ((@pos + bits) & ~bits) - @pos
        pad = read(pad_size)
        unless pad.bytes.all?(&:zero?)
          raise InvalidPacketException, "Alignment bytes are not NUL"
        end
      else
        raise ArgumentError, "Unsupported alignment #{alignment}"
      end
    end
  end

  # better Type


  # basic vs container
  # basic is fixed or string-like
  module Data
    class Base
      # value: from raw_message
      # def initialize
    end

    # ughh bad naming? explain?
    class Basic < Base 
      def self.is_basic?; true; end

      attr_reader :value

      def initialize(value)
        @value = value
      end
    end

    class Fixed < Basic
      def self.is_fixed?; true; end

      # most Fixed types are valid
      # whatever bits from the wire are used to initialize them
      def self.from_raw(value)
        new(value)
      end
    end
    
    class StringLike < Basic
      def self.is_fixed?; false; end
    end

    class Container < Base
      def self.is_basic?; false; end
      def self.is_fixed?; false; end
    end

    Format = ::Struct.new(:little, :big)

    class Byte < Fixed
      def self.type_code; "y"; end
      def self.alignment; 1; end
      FORMAT = Format.new("C", "C")
      def self.format; FORMAT; end
    end

    # like UInt32 but only 0 and 1 are valid
    class Boolean < Fixed
      def self.type_code; "b"; end
      def self.alignment; 4; end
      FORMAT = Format.new("L<", "L>")
      def self.format; FORMAT; end

      def self.from_raw(value)
        unless [0, 1].member?(value)
          raise InvalidPacketException, "BOOLEAN must be 0 or 1, found #{value}"
        end

        new(value == 1)
      end        
    end

    class Int16 < Fixed
      def self.type_code; "n"; end
      def self.alignment; 2; end
      FORMAT = Format.new("s<", "s>")
      def self.format; FORMAT; end
    end

    class UInt16 < Fixed
      def self.type_code; "q"; end
      def self.alignment; 2; end
      FORMAT = Format.new("S<", "S>")
      def self.format; FORMAT; end

      # checked vs unchecked? type ok? domain ok?
      def initialize(value)
        @value = value
      end
    end

    class Int32 < Fixed
      def self.type_code; "i"; end
      def self.alignment; 4; end
      FORMAT = Format.new("l<", "l>")
      def self.format; FORMAT; end
    end

    class UInt32 < Fixed
      def self.type_code; "u"; end
      def self.alignment; 4; end
      FORMAT = Format.new("L<", "L>")
      def self.format; FORMAT; end
    end

    class Int64 < Fixed
      def self.type_code; "x"; end
      def self.alignment; 8; end
      FORMAT = Format.new("q<", "q>")
      def self.format; FORMAT; end
    end

    class UInt64 < Fixed
      def self.type_code; "t"; end
      def self.alignment; 8; end
      FORMAT = Format.new("Q<", "Q>")
      def self.format; FORMAT; end
    end

    class Double < Fixed
      def self.type_code; "d"; end
      def self.alignment; 8; end
      FORMAT = Format.new("E", "G")
      def self.format; FORMAT; end
    end

    class String < StringLike
      def self.type_code; "s"; end
      def self.alignment; 4; end
      def self.size_class; UInt32; end

      def self.from_raw(value)
        value.force_encoding("UTF-8")
        new(value)
      end
    end

    class ObjectPath < StringLike
      def self.type_code; "o"; end
      def self.alignment; 4; end
      def self.size_class; UInt32; end

      def self.from_raw(value)
        # TODO: validate what got sent
        new(value)
      end
    end

    class Signature < StringLike
      def self.type_code; "g"; end
      def self.alignment; 1; end
      def self.size_class; Byte; end

      def self.from_raw(value)
        # TODO: validate what got sent
        new(value)
      end
    end

    # FIXME: this is dumb, does not accommodate Hashes
    class Array < Container
      def self.type_code; "a"; end
      def self.alignment; 4; end

      # TODO: check that Hash keys are basic types
      def self.from_child_bases(value)
        new(value)
      end
    end

    class Struct < Container
      def self.type_code; "r"; end
      def self.alignment; 8; end

      def self.from_child_bases(value)
        value.freeze
        new(value)
      end
    end

    class Variant < Container
      def self.type_code; "v"; end
      def self.alignment; 1; end

      def self.from_child_base(value)
        new(value)
      end
    end

    # Fixme kinda internal; have a Hash?
    class DictEntry < Container
      def self.type_code; "e"; end
      def self.alignment; 8; end
    end

    class UnixFD < Fixed
      def self.type_code; "h"; end
      def self.alignment; 4; end
    end

    consts = constants.map { |c_sym| const_get(c_sym) }
    classes = consts.find_all { |c| c.respond_to?(:type_code) }
    by_type_code = classes.map { |cl| [cl.type_code, cl] }.to_h

    # { "b" => Data::Boolean, "s" => Data::String, ...}
    BY_TYPE_CODE = by_type_code
  end
end
