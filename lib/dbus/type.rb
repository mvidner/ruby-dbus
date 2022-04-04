# frozen_string_literal: true

# dbus/type.rb - module containing low-level D-Bus data type information
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # Like a {Signature} but containing only a single complete type.
  #
  # For documentation purposes only.
  class SingleCompleteType < String; end

  # Zero or more {SingleCompleteType}s; its own type code is "g".
  # For example "ssv" for a method taking two Strings and a Variant/
  #
  # For documentation purposes only.
  class Signature < String; end

  # Similar to {Signature} but for {DBus::Object.define_method},
  # contains names and direction of the parameters.
  # For example "in query:s, in case_sensitive:b, out results:ao".
  #
  # For documentation purposes only.
  class Prototype < String; end

  # = D-Bus type module
  #
  # This module containts the constants of the types specified in the D-Bus
  # protocol.
  #
  # Corresponds to {SingleCompleteType}.
  #
  # See also {DBus::Data::Signature}
  class Type
    # Mapping from type number to name and alignment.
    TYPE_MAPPING = {
      0 => ["INVALID", nil],
      "y" => ["BYTE", 1],
      "b" => ["BOOLEAN", 4],
      "n" => ["INT16", 2],
      "q" => ["UINT16", 2],
      "i" => ["INT32", 4],
      "u" => ["UINT32", 4],
      "x" => ["INT64", 8],
      "t" => ["UINT64", 8],
      "d" => ["DOUBLE", 8],
      "r" => ["STRUCT", 8],
      "a" => ["ARRAY", 4],
      "v" => ["VARIANT", 1],
      "o" => ["OBJECT_PATH", 4],
      "s" => ["STRING", 4],
      "g" => ["SIGNATURE", 1],
      "e" => ["DICT_ENTRY", 8],
      "h" => ["UNIX_FD", 4]
    }.freeze
    # Defines the set of constants
    TYPE_MAPPING.each_pair do |key, value|
      Type.const_set(value.first, key)
    end

    # Exception raised when an unknown/incorrect type is encountered.
    class SignatureException < Exception
    end

    # Formerly this was a Module and there was a DBus::Type::Type class
    # but the class got too prominent to keep its double double name.
    # This is for backward compatibility.
    Type = self # rubocop:disable Naming/ConstantName

    # @return [String] the signature type character, eg "s" or "e".
    attr_reader :sigtype
    # @return [Array<Type>] contained member types.
    attr_reader :members

    # Use {DBus.type} instead, because this allows constructing
    # incomplete or invalid types, for backward compatibility.
    #
    # @param abstract [Boolean] allow abstract types "r" and "e"
    #   (Enabled for internal usage by {Parser}.)
    def initialize(sigtype, abstract: false)
      if !TYPE_MAPPING.keys.member?(sigtype)
        case sigtype
        when ")"
          raise SignatureException, "STRUCT unexpectedly closed: )"
        when "}"
          raise SignatureException, "DICT_ENTRY unexpectedly closed: }"
        else
          raise SignatureException, "Unknown type code #{sigtype.inspect}"
        end
      end

      unless abstract
        case sigtype
        when STRUCT
          raise SignatureException, "Abstract STRUCT, use \"(...)\" instead of \"#{STRUCT}\""
        when DICT_ENTRY
          raise SignatureException, "Abstract DICT_ENTRY, use \"{..}\" instead of \"#{DICT_ENTRY}\""
        end
      end

      @sigtype = sigtype
      @members = []
    end

    # Return the required alignment for the type.
    def alignment
      TYPE_MAPPING[@sigtype].last
    end

    # Return a string representation of the type according to the
    # D-Bus specification.
    def to_s
      case @sigtype
      when STRUCT
        "(#{@members.collect(&:to_s).join})"
      when ARRAY
        "a#{child}"
      when DICT_ENTRY
        "{#{@members.collect(&:to_s).join}}"
      else
        if !TYPE_MAPPING.keys.member?(@sigtype)
          raise NotImplementedError
        end

        @sigtype.chr
      end
    end

    # Add a new member type _item_.
    def <<(item)
      if ![STRUCT, ARRAY, DICT_ENTRY].member?(@sigtype)
        raise SignatureException
      end
      raise SignatureException if @sigtype == ARRAY && !@members.empty?

      if @sigtype == DICT_ENTRY
        case @members.size
        when 2
          raise SignatureException, "DICT_ENTRY must have 2 subtypes, found 3 or more in #{@signature}"
        when 0
          if [STRUCT, ARRAY, DICT_ENTRY, VARIANT].member?(item.sigtype)
            raise SignatureException, "DICT_ENTRY key must be basic (non-container)"
          end
        end
      end
      @members << item
    end

    # Return the first contained member type.
    def child
      @members[0]
    end

    def inspect
      s = TYPE_MAPPING[@sigtype].first
      if [STRUCT, ARRAY].member?(@sigtype)
        s += ": #{@members.inspect}"
      end
      s
    end

    # = D-Bus type parser class
    #
    # Helper class to parse a type signature in the protocol.
    # @api private
    class Parser
      # Create a new parser for the given _signature_.
      # @param signature [Signature]
      def initialize(signature)
        @signature = signature
        if signature.size > 255
          msg = "Potential signature is longer than 255 characters (#{@signature.size}): #{@signature}"
          raise SignatureException, msg
        end

        @idx = 0
      end

      # Returns the next character from the signature.
      def nextchar
        c = @signature[@idx]
        @idx += 1
        c
      end

      # Parse one character _char_ of the signature.
      # @param for_array [Boolean] are we parsing an immediate child of an ARRAY
      # @return [Type]
      def parse_one(char, for_array: false)
        res = nil
        case char
        when "a"
          res = Type.new(ARRAY)
          char = nextchar
          raise SignatureException, "Empty ARRAY in #{@signature}" if char.nil?

          child = parse_one(char, for_array: true)
          res << child
        when "("
          res = Type.new(STRUCT, abstract: true)
          while (char = nextchar) && char != ")"
            res << parse_one(char)
          end
          raise SignatureException, "STRUCT not closed in #{@signature}" if char.nil?
          raise SignatureException, "Empty STRUCT in #{@signature}" if res.members.empty?
        when "{"
          raise SignatureException, "DICT_ENTRY not an immediate child of an ARRAY" unless for_array

          res = Type.new(DICT_ENTRY, abstract: true)

          # key type, value type
          2.times do |i|
            char = nextchar
            raise SignatureException, "DICT_ENTRY not closed in #{@signature}" if char.nil?

            raise SignatureException, "DICT_ENTRY must have 2 subtypes, found #{i} in #{@signature}" if char == "}"

            res << parse_one(char)
          end

          # closing "}"
          char = nextchar
          raise SignatureException, "DICT_ENTRY not closed in #{@signature}" if char.nil?

          raise SignatureException, "DICT_ENTRY must have 2 subtypes, found 3 or more in #{@signature}" if char != "}"
        else
          res = Type.new(char)
        end
        res
      end

      # Parse the entire signature, return a DBus::Type object.
      # @return [Array<Type>]
      def parse
        @idx = 0
        ret = []
        while (c = nextchar)
          ret << parse_one(c)
        end
        ret
      end

      # Parse one {SingleCompleteType}
      # @return [Type]
      def parse1
        c = nextchar
        raise SignatureException, "Empty signature, expecting a Single Complete Type" if c.nil?

        t = parse_one(c)
        raise SignatureException, "Has more than a Single Complete Type: #{@signature}" unless nextchar.nil?

        t
      end
    end
  end

  # shortcuts

  # Parse a String to a valid {DBus::Type}.
  # This is prefered to {Type#initialize} which allows
  # incomplete or invalid types.
  # @param string_type [SingleCompleteType]
  # @return [DBus::Type]
  # @raise SignatureException
  def type(string_type)
    Type::Parser.new(string_type).parse1
  end
  module_function :type

  # Parse a String to zero or more {DBus::Type}s.
  # @param string_type [Signature]
  # @return [Array<DBus::Type>]
  # @raise SignatureException
  def types(string_type)
    Type::Parser.new(string_type).parse
  end
  module_function :types

  # Make an explicit [Type, value] pair
  # @param string_type [SingleCompleteType]
  # @param value [::Object]
  # @return [Array(DBus::Type::Type,::Object)]
  def variant(string_type, value)
    [type(string_type), value]
  end
  module_function :variant
end
