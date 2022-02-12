# frozen_string_literal: true

# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "socket"

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # Exception raised when an invalid packet is encountered.
  class InvalidPacketException < Exception
  end

  # = D-Bus packet unmarshaller class
  #
  # Class that handles the conversion (unmarshalling) of payload data
  # to Array.
  class PacketUnmarshaller
    # Index pointer that points to the byte in the data that is
    # currently being processed.
    #
    # Used to kown what part of the buffer has been consumed by unmarshalling.
    # FIXME: Maybe should be accessed with a "consumed_size" method.
    attr_reader :idx

    # Create a new unmarshaller for the given data _buffer_ and _endianness_.
    def initialize(buffer, endianness)
      @buffy = buffer.dup
      @endianness = endianness
      case @endianness
      when BIG_END
        @uint32 = "N"
        @uint16 = "n"
        @double = "G"
      when LIL_END
        @uint32 = "V"
        @uint16 = "v"
        @double = "E"
      else
        raise InvalidPacketException, "Incorrect endianness #{@endianness}"
      end
      @idx = 0
    end

    # Unmarshall the buffer for a given _signature_ and length _len_.
    # Return an array of unmarshalled objects
    # @param signature [Signature]
    # @param len [Integer,nil] if given, and there is not enough data
    #   in the buffer, raise {IncompleteBufferException}
    # @return [Array<::Object>]
    # @raise IncompleteBufferException
    def unmarshall(signature, len = nil)
      raise IncompleteBufferException if len && @buffy.bytesize < @idx + len

      sigtree = Type::Parser.new(signature).parse
      ret = []
      sigtree.each do |elem|
        ret << do_parse(elem)
      end
      ret
    end

    # Align the pointer index on a byte index of _a_, where a
    # must be 1, 2, 4 or 8.
    def align(a)
      case a
      when 1
        nil
      when 2, 4, 8
        bits = a - 1
        @idx = @idx + bits & ~bits
        raise IncompleteBufferException if @idx > @buffy.bytesize
      else
        raise "Unsupported alignment #{a}"
      end
    end

    ###############################################################
    # FIXME: does anyone except the object itself call the above methods?
    # Yes : Message marshalling code needs to align "body" to 8 byte boundary
    private

    # Retrieve the next _nbytes_ number of bytes from the buffer.
    def read(nbytes)
      raise IncompleteBufferException if @idx + nbytes > @buffy.bytesize

      ret = @buffy.slice(@idx, nbytes)
      @idx += nbytes
      ret
    end

    # Read the string length and string itself from the buffer.
    # Return the string.
    def read_string
      align(4)
      str_sz = read(4).unpack1(@uint32)
      ret = @buffy.slice(@idx, str_sz)
      raise IncompleteBufferException if @idx + str_sz + 1 > @buffy.bytesize

      @idx += str_sz
      if @buffy[@idx].ord != 0
        raise InvalidPacketException, "String is not nul-terminated"
      end

      @idx += 1
      # no exception, see check above
      ret
    end

    # Read the signature length and signature itself from the buffer.
    # Return the signature.
    def read_signature
      str_sz = read(1).unpack1("C")
      ret = @buffy.slice(@idx, str_sz)
      raise IncompleteBufferException if @idx + str_sz + 1 >= @buffy.bytesize

      @idx += str_sz
      if @buffy[@idx].ord != 0
        raise InvalidPacketException, "Type is not nul-terminated"
      end

      @idx += 1
      # no exception, see check above
      ret
    end

    # Based on the _signature_ type, retrieve a packet from the buffer
    # and return it.
    def do_parse(signature)
      packet = nil
      case signature.sigtype
      when Type::BYTE
        packet = read(1).unpack1("C")
      when Type::UINT16
        align(2)
        packet = read(2).unpack1(@uint16)
      when Type::INT16
        align(2)
        packet = read(2).unpack1(@uint16)
        if (packet & 0x8000) != 0
          packet -= 0x10000
        end
      when Type::UINT32, Type::UNIX_FD
        align(4)
        packet = read(4).unpack1(@uint32)
      when Type::INT32
        align(4)
        packet = read(4).unpack1(@uint32)
        if (packet & 0x80000000) != 0
          packet -= 0x100000000
        end
      when Type::UINT64
        align(8)
        packet_l = read(4).unpack1(@uint32)
        packet_h = read(4).unpack1(@uint32)
        packet = if @endianness == LIL_END
                   packet_l + packet_h * 2**32
                 else
                   packet_l * 2**32 + packet_h
                 end
      when Type::INT64
        align(8)
        packet_l = read(4).unpack1(@uint32)
        packet_h = read(4).unpack1(@uint32)
        packet = if @endianness == LIL_END
                   packet_l + packet_h * 2**32
                 else
                   packet_l * 2**32 + packet_h
                 end
        if (packet & 0x8000000000000000) != 0
          packet -= 0x10000000000000000
        end
      when Type::DOUBLE
        align(8)
        packet = read(8).unpack1(@double)
      when Type::BOOLEAN
        align(4)
        v = read(4).unpack1(@uint32)
        raise InvalidPacketException if ![0, 1].member?(v)

        packet = (v == 1)
      when Type::ARRAY
        align(4)
        # checks please
        array_sz = read(4).unpack1(@uint32)
        raise InvalidPacketException if array_sz > 67_108_864

        align(signature.child.alignment)
        raise IncompleteBufferException if @idx + array_sz > @buffy.bytesize

        packet = []
        start_idx = @idx
        while @idx - start_idx < array_sz
          packet << do_parse(signature.child)
        end

        if signature.child.sigtype == Type::DICT_ENTRY
          packet = Hash[packet]
        end
      when Type::STRUCT
        align(8)
        packet = []
        signature.members.each do |elem|
          packet << do_parse(elem)
        end
      when Type::VARIANT
        string = read_signature
        # error checking please
        sig = Type::Parser.new(string).parse[0]
        align(sig.alignment)
        packet = do_parse(sig)
      when Type::OBJECT_PATH
        packet = read_string
      when Type::STRING
        packet = read_string
        packet.force_encoding("UTF-8")
      when Type::SIGNATURE
        packet = read_signature
      when Type::DICT_ENTRY
        align(8)
        key = do_parse(signature.members[0])
        value = do_parse(signature.members[1])
        packet = [key, value]
      else
        raise NotImplementedError,
              "sigtype: #{signature.sigtype} (#{signature.sigtype.chr})"
      end
      packet
    end
  end

  # D-Bus packet marshaller class
  #
  # Class that handles the conversion (marshalling) of Ruby objects to
  # (binary) payload data.
  class PacketMarshaller
    # The current or result packet.
    # FIXME: allow access only when marshalling is finished
    attr_reader :packet

    # Create a new marshaller, setting the current packet to the
    # empty packet.
    def initialize(offset = 0)
      @packet = ""
      @offset = offset # for correct alignment of nested marshallers
    end

    # Round _n_ up to the specified power of two, _a_
    def num_align(n, a)
      case a
      when 1, 2, 4, 8
        bits = a - 1
        n + bits & ~bits
      else
        raise "Unsupported alignment"
      end
    end

    # Align the buffer with NULL (\0) bytes on a byte length of _a_.
    def align(a)
      @packet = @packet.ljust(num_align(@offset + @packet.bytesize, a) - @offset, 0.chr)
    end

    # Append the the string _str_ itself to the packet.
    def append_string(str)
      align(4)
      @packet += [str.bytesize].pack("L") + [str].pack("Z*")
    end

    # Append the the signature _signature_ itself to the packet.
    def append_signature(str)
      @packet += "#{str.bytesize.chr}#{str}\u0000"
    end

    # Append the array type _type_ to the packet and allow for appending
    # the child elements.
    def array(type)
      # Thanks to Peter Rullmann for this line
      align(4)
      sizeidx = @packet.bytesize
      @packet += "ABCD"
      align(type.alignment)
      contentidx = @packet.bytesize
      yield
      sz = @packet.bytesize - contentidx
      raise InvalidPacketException if sz > 67_108_864

      @packet[sizeidx...sizeidx + 4] = [sz].pack("L")
    end

    # Align and allow for appending struct fields.
    def struct
      align(8)
      yield
    end

    # Append a value _val_ to the packet based on its _type_.
    #
    # Host native endianness is used, declared in Message#marshall
    def append(type, val)
      raise TypeException, "Cannot send nil" if val.nil?

      type = type.chr if type.is_a?(Integer)
      type = Type::Parser.new(type).parse[0] if type.is_a?(String)
      case type.sigtype
      when Type::BYTE
        @packet += val.chr
      when Type::UINT32, Type::UNIX_FD
        align(4)
        @packet += [val].pack("L")
      when Type::UINT64
        align(8)
        @packet += [val].pack("Q")
      when Type::INT64
        align(8)
        @packet += [val].pack("q")
      when Type::INT32
        align(4)
        @packet += [val].pack("l")
      when Type::UINT16
        align(2)
        @packet += [val].pack("S")
      when Type::INT16
        align(2)
        @packet += [val].pack("s")
      when Type::DOUBLE
        align(8)
        @packet += [val].pack("d")
      when Type::BOOLEAN
        align(4)
        @packet += if val
                     [1].pack("L")
                   else
                     [0].pack("L")
                   end
      when Type::OBJECT_PATH
        append_string(val)
      when Type::STRING
        append_string(val)
      when Type::SIGNATURE
        append_signature(val)
      when Type::VARIANT
        append_variant(val)
      when Type::ARRAY
        append_array(type.child, val)
      when Type::STRUCT, Type::DICT_ENTRY
        # TODO: use duck typing, val.respond_to?
        raise TypeException, "Struct/DE expects an Array" if !val.is_a?(Array)
        if type.sigtype == Type::DICT_ENTRY && val.size != 2
          raise TypeException, "Dict entry expects a pair"
        end
        if type.members.size != val.size
          raise TypeException, "Struct/DE has #{val.size} elements but type info for #{type.members.size}"
        end

        struct do
          type.members.zip(val).each do |t, v|
            append(t, v)
          end
        end
      else
        raise NotImplementedError,
              "sigtype: #{type.sigtype} (#{type.sigtype.chr})"
      end
    end

    def append_variant(val)
      vartype = nil
      if val.is_a?(Array) && val.size == 2
        case val[0]
        when DBus::Type::Type
          vartype, vardata = val
        when String
          begin
            parsed = Type::Parser.new(val[0]).parse
            vartype = parsed[0] if parsed.size == 1
            vardata = val[1]
          rescue Type::SignatureException
            # no assignment
          end
        end
      end
      if vartype.nil?
        vartype, vardata = PacketMarshaller.make_variant(val)
        vartype = Type::Parser.new(vartype).parse[0]
      end

      append_signature(vartype.to_s)
      align(vartype.alignment)
      sub = PacketMarshaller.new(@offset + @packet.bytesize)
      sub.append(vartype, vardata)
      @packet += sub.packet
    end

    # @param child_type [DBus::Type::Type]
    def append_array(child_type, val)
      if val.is_a?(Hash)
        raise TypeException, "Expected an Array but got a Hash" if child_type.sigtype != Type::DICT_ENTRY

        # Damn ruby rocks here
        val = val.to_a
      end
      # If string is recieved and ay is expected, explode the string
      if val.is_a?(String) && child_type.sigtype == Type::BYTE
        val = val.bytes
      end
      if !val.is_a?(Enumerable)
        raise TypeException, "Expected an Enumerable of #{child_type.inspect} but got a #{val.class}"
      end

      array(child_type) do
        val.each do |elem|
          append(child_type, elem)
        end
      end
    end

    # Make a [signature, value] pair for a variant
    def self.make_variant(value)
      # TODO: mix in _make_variant to String, Integer...
      if value == true
        ["b", true]
      elsif value == false
        ["b", false]
      elsif value.nil?
        ["b", nil]
      elsif value.is_a? Float
        ["d", value]
      elsif value.is_a? Symbol
        ["s", value.to_s]
      elsif value.is_a? Array
        ["av", value.map { |i| make_variant(i) }]
      elsif value.is_a? Hash
        h = {}
        value.each_key { |k| h[k] = make_variant(value[k]) }
        ["a{sv}", h]
      elsif value.respond_to? :to_str
        ["s", value.to_str]
      elsif value.respond_to? :to_int
        i = value.to_int
        if (-2_147_483_648...2_147_483_648).cover?(i)
          ["i", i]
        else
          ["x", i]
        end
      end
    end
  end
end
