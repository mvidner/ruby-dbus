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

  # Represents the D-Bus types.
  #
  # Corresponds to {SingleCompleteType}.
  # Instances are immutable/frozen once fully constructed.
  #
  # See also {DBus::Data::Signature} which is "type on the wire".
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

      @sigtype = sigtype.freeze
      @members = [] # not frozen yet, Parser#parse_one or Factory will do it
      freeze
    end

    # A Type is equal to
    # - another Type with the same string representation
    # - a String ({SingleCompleteType}) describing the type
    def ==(other)
      case other
      when ::String
        to_s == other
      else
        eql?(other)
      end
    end

    # A Type is eql? to
    # - another Type with the same string representation
    #
    # Hash key equality
    # See https://ruby-doc.org/core-3.0.0/Object.html#method-i-eql-3F
    def eql?(other)
      return false unless other.is_a?(Type)

      @sigtype == other.sigtype && @members == other.members
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
        @sigtype.chr
      end
    end

    # Add a new member type _item_.
    # @param item [Type]
    def <<(item)
      raise ArgumentError unless item.is_a?(Type)

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
      if [STRUCT, ARRAY, DICT_ENTRY].member?(@sigtype)
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
        res.members.freeze
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
        ret.freeze
      end

      # Parse one {SingleCompleteType}
      # @return [Type]
      def parse1
        c = nextchar
        raise SignatureException, "Empty signature, expecting a Single Complete Type" if c.nil?

        t = parse_one(c)
        raise SignatureException, "Has more than a Single Complete Type: #{@signature}" unless nextchar.nil?

        t.freeze
      end
    end

    class Factory
      # @param type [Type,SingleCompleteType,Class]
      # @see from_plain_class
      # @return [Type] (frozen)
      def self.make_type(type)
        case type
        when Type
          type
        when String
          DBus.type(type)
        when Class
          from_plain_class(type)
        else
          msg = "Expecting DBus::Type, DBus::SingleCompleteType(aka ::String), or Class, got #{type.inspect}"
          raise ArgumentError, msg
        end
      end

      # Make a {Type} corresponding to some plain classes:
      # - String
      # - Float
      # - DBus::ObjectPath
      # - DBus::Signature, DBus::SingleCompleteType
      # @param klass [Class]
      # @return [Type] (frozen)
      def self.from_plain_class(klass)
        @signature_type ||= DBus.type(SIGNATURE)
        @class_to_type ||= {
          DBus::ObjectPath => DBus.type(OBJECT_PATH),
          DBus::Signature => @signature_type,
          DBus::SingleCompleteType => @signature_type,
          String => DBus.type(STRING),
          Float => DBus.type(DOUBLE)
        }
        t = @class_to_type[klass]
        raise ArgumentError, "Cannot convert plain class #{klass} to a D-Bus type" if t.nil?

        t
      end
    end

    # Syntactic helper for constructing an array Type.
    # You may be looking for {Data::Array} instead.
    # @example
    #   t = Type::Array[Type::INT16]
    class ArrayFactory < Factory
      # @param member_type [Type,SingleCompleteType]
      # @return [Type] (frozen)
      def self.[](member_type)
        t = Type.new(ARRAY)
        t << make_type(member_type)
        t.members.freeze
        t
      end
    end

    # @example
    #   t = Type::Array[Type::INT16]
    Array = ArrayFactory

    # Syntactic helper for constructing a hash Type.
    # You may be looking for {Data::Array} and {Data::DictEntry} instead.
    # @example
    #   t = Type::Hash[Type::STRING, Type::VARIANT]
    class HashFactory < Factory
      # @param key_type [Type,SingleCompleteType]
      # @param value_type [Type,SingleCompleteType]
      # @return [Type] (frozen)
      def self.[](key_type, value_type)
        t = Type.new(ARRAY)
        de = Type.new(DICT_ENTRY, abstract: true)
        de << make_type(key_type)
        de << make_type(value_type)
        de.members.freeze
        t << de
        t.members.freeze
        t
      end
    end

    # @example
    #   t = Type::Hash[Type::INT16]
    Hash = HashFactory

    # Syntactic helper for constructing a struct Type.
    # You may be looking for {Data::Struct} instead.
    # @example
    #   t = Type::Struct[Type::INT16, Type::STRING]
    class StructFactory < Factory
      # @param member_types [::Array<Type,SingleCompleteType>]
      # @return [Type] (frozen)
      def self.[](*member_types)
        raise ArgumentError if member_types.empty?

        t = Type.new(STRUCT, abstract: true)
        member_types.each do |mt|
          t << make_type(mt)
        end
        t.members.freeze
        t
      end
    end

    # @example
    #   t = Type::Struct[Type::INT16, Type::STRING]
    Struct = StructFactory
  end

  # shortcuts

  # Parse a String to a valid {DBus::Type}.
  # This is prefered to {Type#initialize} which allows
  # incomplete or invalid types.
  # @param string_type [SingleCompleteType]
  # @return [DBus::Type] (frozen)
  # @raise SignatureException
  def type(string_type)
    Type::Parser.new(string_type).parse1
  end
  module_function :type

  # Parse a String to zero or more {DBus::Type}s.
  # @param string_type [Signature]
  # @return [Array<DBus::Type>] (frozen)
  # @raise SignatureException
  def types(string_type)
    Type::Parser.new(string_type).parse
  end
  module_function :types

  # Make an explicit [Type, value] pair
  # @param string_type [SingleCompleteType]
  # @param value [::Object]
  # @return [Array(DBus::Type::Type,::Object)]
  # @deprecated Use {Data::Variant#initialize} instead
  def variant(string_type, value)
    Data::Variant.new(value, member_type: string_type)
  end
  module_function :variant
end
