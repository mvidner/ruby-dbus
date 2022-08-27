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

require_relative "../dbus/type"

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
  # to #{::Object}s (in **plain** mode) or to {Data::Base} (in **exact** mode)
  #
  # Spelling note: this codebase always uses a double L
  # in the "marshall" word and its inflections.
  class PacketUnmarshaller
    # Create a new unmarshaller for the given data *buffer*.
    # @param buffer [String]
    # @param endianness [:little,:big]
    def initialize(buffer, endianness)
      # TODO: this dup can be avoided if we can prove
      # that an IncompleteBufferException leaves the original *buffer* intact
      buffer = buffer.dup
      @raw_msg = RawMessage.new(buffer, endianness)
    end

    # Unmarshall the buffer for a given _signature_ and length _len_.
    # Return an array of unmarshalled objects.
    # @param signature [Signature]
    # @param len [Integer,nil] if given, and there is not enough data
    #   in the buffer, raise {IncompleteBufferException}
    # @param mode [:plain,:exact]
    # @return [Array<::Object,DBus::Data::Base>]
    #    Objects in `:plain` mode, {DBus::Data::Base} in `:exact` mode
    #    The array size corresponds to the number of types in *signature*.
    # @raise IncompleteBufferException
    # @raise InvalidPacketException
    def unmarshall(signature, len = nil, mode: :plain)
      @raw_msg.want!(len) if len

      sigtree = Type::Parser.new(signature).parse
      ret = []
      sigtree.each do |elem|
        ret << do_parse(elem, mode: mode)
      end
      ret
    end

    # after the headers, the body starts 8-aligned
    def align_body
      @raw_msg.align(8)
    end

    # @return [Integer]
    def consumed_size
      @raw_msg.pos
    end

    private

    # @param data_class [Class] a subclass of Data::Base (specific?)
    # @return [::Integer,::Float]
    def aligned_read_value(data_class)
      @raw_msg.align(data_class.alignment)
      bytes = @raw_msg.read(data_class.alignment)
      bytes.unpack1(data_class.format[@raw_msg.endianness])
    end

    # Based on the _signature_ type, retrieve a packet from the buffer
    # and return it.
    # @param signature [Type]
    # @param mode [:plain,:exact]
    # @return [Data::Base]
    def do_parse(signature, mode: :plain)
      # FIXME: better naming for packet vs value
      packet = nil
      data_class = Data::BY_TYPE_CODE[signature.sigtype]

      if data_class.nil?
        raise NotImplementedError,
              "sigtype: #{signature.sigtype} (#{signature.sigtype.chr})"
      end

      if data_class.fixed?
        value = aligned_read_value(data_class)
        packet = data_class.from_raw(value, mode: mode)
      elsif data_class.basic?
        size = aligned_read_value(data_class.size_class)
        # @raw_msg.align(data_class.alignment)
        # ^ is not necessary because we've just read a suitably-aligned *size*
        value = @raw_msg.read(size)
        nul = @raw_msg.read(1)
        if nul != "\u0000"
          raise InvalidPacketException, "#{data_class} is not NUL-terminated"
        end

        packet = data_class.from_raw(value, mode: mode)
      else
        @raw_msg.align(data_class.alignment)
        case signature.sigtype
        when Type::STRUCT, Type::DICT_ENTRY
          values = signature.members.map do |child_sig|
            do_parse(child_sig, mode: mode)
          end
          packet = data_class.from_items(values, mode: mode, type: signature)

        when Type::VARIANT
          data_sig = do_parse(Data::Signature.type, mode: :exact) # -> Data::Signature
          types = Type::Parser.new(data_sig.value).parse # -> Array<Type>
          unless types.size == 1
            raise InvalidPacketException, "VARIANT must contain 1 value, #{types.size} found"
          end

          type = types.first
          value = do_parse(type, mode: mode)
          packet = data_class.from_items(value, mode: mode, member_type: type)

        when Type::ARRAY
          array_bytes = aligned_read_value(Data::UInt32)
          if array_bytes > 67_108_864
            raise InvalidPacketException, "ARRAY body longer than 64MiB"
          end

          # needed here because of empty arrays
          @raw_msg.align(signature.child.alignment)

          items = []
          end_pos = @raw_msg.pos + array_bytes
          while @raw_msg.pos < end_pos
            item = do_parse(signature.child, mode: mode)
            items << item
          end
          is_hash = signature.child.sigtype == Type::DICT_ENTRY
          packet = data_class.from_items(items, mode: mode, type: signature, hash: is_hash)
        end
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
    # @return [String]
    attr_reader :packet

    # @return [:little,:big]
    attr_reader :endianness

    # Create a new marshaller, setting the current packet to the
    # empty packet.
    def initialize(offset = 0, endianness: HOST_ENDIANNESS)
      @endianness = endianness
      @packet = ""
      @offset = offset # for correct alignment of nested marshallers
    end

    # Round _num_ up to the specified power of two, _alignment_
    def num_align(num, alignment)
      case alignment
      when 1, 2, 4, 8
        bits = alignment - 1
        num + bits & ~bits
      else
        raise ArgumentError, "Unsupported alignment #{alignment}"
      end
    end

    # Align the buffer with NULL (\0) bytes on a byte length of _alignment_.
    def align(alignment)
      pad_count = num_align(@offset + @packet.bytesize, alignment) - @offset
      @packet = @packet.ljust(pad_count, 0.chr)
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

      sz_data = Data::UInt32.new(sz)
      @packet[sizeidx...sizeidx + 4] = sz_data.marshall(endianness)
    end

    # Align and allow for appending struct fields.
    def struct
      align(8)
      yield
    end

    # Append a value _val_ to the packet based on its _type_.
    #
    # Host native endianness is used, declared in Message#marshall
    #
    # @param type [SingleCompleteType] (or Integer or {Type})
    # @param val [::Object]
    def append(type, val)
      raise TypeException, "Cannot send nil" if val.nil?

      type = type.chr if type.is_a?(Integer)
      type = Type::Parser.new(type).parse[0] if type.is_a?(String)
      # type is [Type] now
      data_class = Data::BY_TYPE_CODE[type.sigtype]
      if data_class.nil?
        raise NotImplementedError,
              "sigtype: #{type.sigtype} (#{type.sigtype.chr})"
      end

      if data_class.fixed?
        align(data_class.alignment)
        data = data_class.new(val)
        @packet += data.marshall(endianness)
      elsif data_class.basic?
        val = val.value if val.is_a?(Data::Basic)
        align(data_class.size_class.alignment)
        size_data = data_class.size_class.new(val.bytesize)
        @packet += size_data.marshall(endianness)
        # Z* makes a binary string, as opposed to interpolation
        @packet += [val].pack("Z*")
      else
        case type.sigtype

        when Type::VARIANT
          append_variant(val)
        when Type::ARRAY
          val = val.exact_value if val.is_a?(Data::Array)
          append_array(type.child, val)
        when Type::STRUCT, Type::DICT_ENTRY
          val = val.exact_value if val.is_a?(Data::Struct) || val.is_a?(Data::DictEntry)
          unless val.is_a?(Array) || val.is_a?(Struct)
            type_name = Type::TYPE_MAPPING[type.sigtype].first
            raise TypeException, "#{type_name} expects an Array or Struct, seen #{val.class}"
          end

          if type.sigtype == Type::DICT_ENTRY && val.size != 2
            raise TypeException, "DICT_ENTRY expects a pair"
          end

          if type.members.size != val.size
            type_name = Type::TYPE_MAPPING[type.sigtype].first
            raise TypeException, "#{type_name} has #{val.size} elements but type info for #{type.members.size}"
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
    end

    def append_variant(val)
      vartype = nil
      if val.is_a?(DBus::Data::Variant)
        vartype = val.member_type
        vardata = val.exact_value
      elsif val.is_a?(DBus::Data::Container)
        vartype = val.type
        vardata = val.exact_value
      elsif val.is_a?(DBus::Data::Base)
        vartype = val.type
        vardata = val.value
      elsif val.is_a?(Array) && val.size == 2
        case val[0]
        when Type
          vartype, vardata = val
        # Ambiguous but easy to use, because Type
        # cannot construct "as" "a{sv}" easily
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

      append(Data::Signature.type, vartype.to_s)
      align(vartype.alignment)
      sub = PacketMarshaller.new(@offset + @packet.bytesize, endianness: endianness)
      sub.append(vartype, vardata)
      @packet += sub.packet
    end

    # @param child_type [Type]
    def append_array(child_type, val)
      if val.is_a?(Hash)
        raise TypeException, "Expected an Array but got a Hash" if child_type.sigtype != Type::DICT_ENTRY

        # Damn ruby rocks here
        val = val.to_a
      end
      # If string is received and ay is expected, explode the string
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
        key_type = if value.empty?
                     "s"
                   else
                     t, = make_variant(value.first.first)
                     t
                   end
        ["a{#{key_type}v}", h]
      elsif value.respond_to? :to_str
        ["s", value.to_str]
      elsif value.respond_to? :to_int
        i = value.to_int
        if Data::Int32.range.cover?(i)
          ["i", i]
        elsif Data::Int64.range.cover?(i)
          ["x", i]
        else
          ["t", i]
        end
      end
    end
  end
end
