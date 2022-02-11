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
  module Type
    # Mapping from type number to name and alignment.
    TypeMapping = {
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
    TypeMapping.each_pair do |key, value|
      Type.const_set(value.first, key)
    end

    # Exception raised when an unknown/incorrect type is encountered.
    class SignatureException < Exception
    end

    # = D-Bus type conversion class
    #
    # Helper class for representing a D-Bus type.
    class Type
      # Returns the signature type number.
      attr_reader :sigtype
      # Return contained member types.
      attr_reader :members

      # Create a new type instance for type number _sigtype_.
      def initialize(sigtype)
        if !TypeMapping.keys.member?(sigtype)
          raise SignatureException, "Unknown key in signature: #{sigtype.chr}"
        end
        @sigtype = sigtype
        @members = []
      end

      # Return the required alignment for the type.
      def alignment
        TypeMapping[@sigtype].last
      end

      # Return a string representation of the type according to the
      # D-Bus specification.
      def to_s
        case @sigtype
        when STRUCT
          "(" + @members.collect(&:to_s).join + ")"
        when ARRAY
          "a" + child.to_s
        when DICT_ENTRY
          "{" + @members.collect(&:to_s).join + "}"
        else
          if !TypeMapping.keys.member?(@sigtype)
            raise NotImplementedError
          end
          @sigtype.chr
        end
      end

      # Add a new member type _a_.
      def <<(a)
        if ![STRUCT, ARRAY, DICT_ENTRY].member?(@sigtype)
          raise SignatureException
        end
        raise SignatureException if @sigtype == ARRAY && !@members.empty?
        if @sigtype == DICT_ENTRY
          if @members.size == 2
            raise SignatureException, "Dict entries have exactly two members"
          end
          if @members.empty?
            if [STRUCT, ARRAY, DICT_ENTRY].member?(a.sigtype)
              raise SignatureException, "Dict entry keys must be basic types"
            end
          end
        end
        @members << a
      end

      # Return the first contained member type.
      def child
        @members[0]
      end

      def inspect
        s = TypeMapping[@sigtype].first
        if [STRUCT, ARRAY].member?(@sigtype)
          s += ": " + @members.inspect
        end
        s
      end
    end # class Type

    # = D-Bus type parser class
    #
    # Helper class to parse a type signature in the protocol.
    class Parser
      # Create a new parser for the given _signature_.
      def initialize(signature)
        @signature = signature
        @idx = 0
      end

      # Returns the next character from the signature.
      def nextchar
        c = @signature[@idx]
        @idx += 1
        c
      end

      # Parse one character _c_ of the signature.
      def parse_one(c)
        res = nil
        case c
        when "a"
          res = Type.new(ARRAY)
          c = nextchar
          raise SignatureException, "Parse error in #{@signature}" if c.nil?
          child = parse_one(c)
          res << child
        when "("
          res = Type.new(STRUCT)
          while (c = nextchar) && c != ")"
            res << parse_one(c)
          end
          raise SignatureException, "Parse error in #{@signature}" if c.nil?
        when "{"
          res = Type.new(DICT_ENTRY)
          while (c = nextchar) && c != "}"
            res << parse_one(c)
          end
          raise SignatureException, "Parse error in #{@signature}" if c.nil?
        else
          res = Type.new(c)
        end
        res
      end

      # Parse the entire signature, return a DBus::Type object.
      def parse
        @idx = 0
        ret = []
        while (c = nextchar)
          ret << parse_one(c)
        end
        ret
      end
    end # class Parser
  end # module Type

  # shortcuts

  # Parse a String to a DBus::Type::Type
  def type(string_type)
    Type::Parser.new(string_type).parse[0]
  end
  module_function :type

  # Make an explicit [Type, value] pair
  def variant(string_type, value)
    [type(string_type), value]
  end
  module_function :variant
end # module DBus
