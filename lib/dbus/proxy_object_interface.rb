# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2009-2014 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # = D-Bus proxy object interface class
  #
  # A class similar to the normal Interface used as a proxy for remote
  # object interfaces.
  class ProxyObjectInterface
    # The proxied methods contained in the interface.
    attr_accessor :methods
    # The proxied signals contained in the interface.
    attr_accessor :signals
    # The proxy object to which this interface belongs.
    attr_reader :object
    # The name of the interface.
    attr_reader :name

    # Creates a new proxy interface for the given proxy _object_
    # and the given _name_.
    def initialize(object, name)
      @object = object
      @name = name
      @methods = {}
      @signals = {}
    end

    # Returns the string representation of the interface (the name).
    def to_str
      @name
    end

    # Defines a method on the interface from the Method descriptor _m_.
    def define_method_from_descriptor(m)
      m.params.each do |fpar|
        par = fpar.type
        # This is the signature validity check
        Type::Parser.new(par).parse
      end

      singleton_class.class_eval do
        define_method m.name do |*args, &reply_handler|
          if m.params.size != args.size
            raise ArgumentError, "wrong number of arguments (#{args.size} for #{m.params.size})"
          end

          msg = Message.new(Message::METHOD_CALL)
          msg.path = @object.path
          msg.interface = @name
          msg.destination = @object.destination
          msg.member = m.name
          msg.sender = @object.bus.unique_name
          m.params.each do |fpar|
            par = fpar.type
            msg.add_param(par, args.shift)
          end
          ret = @object.bus.send_sync_or_async(msg, &reply_handler)
          if ret.nil? || @object.api.proxy_method_returns_array
            ret
          else
            m.rets.size == 1 ? ret.first : ret
          end
        end
      end

      @methods[m.name] = m
    end

    # Defines a signal from the descriptor _s_.
    def define_signal_from_descriptor(s)
      @signals[s.name] = s
    end

    # Defines a signal or method based on the descriptor _m_.
    def define(m)
      if m.is_a?(Method)
        define_method_from_descriptor(m)
      elsif m.is_a?(Signal)
        define_signal_from_descriptor(m)
      end
    end

    # Defines a proxied method on the interface.
    # Better name: declare_method
    def define_method(methodname, prototype)
      m = Method.new(methodname)
      m.from_prototype(prototype)
      define(m)
    end

    # @overload on_signal(name, &block)
    # @overload on_signal(bus, name, &block)
    # Registers a handler (code block) for a signal with _name_ arriving
    # over the given _bus_. If no block is given, the signal is unregistered.
    # Note that specifying _bus_ is discouraged and the option is kept only for
    # backward compatibility.
    # @return [void]
    def on_signal(bus = @object.bus, name, &block)
      mr = DBus::MatchRule.new.from_signal(self, name)
      if block.nil?
        bus.remove_match(mr)
      else
        bus.add_match(mr) { |msg| block.call(*msg.params) }
      end
    end

    PROPERTY_INTERFACE = "org.freedesktop.DBus.Properties".freeze

    # Read a property.
    # @param propname [String]
    def [](propname)
      ret = object[PROPERTY_INTERFACE].Get(name, propname)
      # this method always returns the single property
      if @object.api.proxy_method_returns_array
        ret[0]
      else
        ret
      end
    end

    # Write a property.
    # @param propname [String]
    # @param value [Object]
    def []=(propname, value)
      object[PROPERTY_INTERFACE].Set(name, propname, value)
    end

    # Read all properties at once, as a hash.
    # @return [Hash{String}]
    def all_properties
      ret = object[PROPERTY_INTERFACE].GetAll(name)
      # this method always returns the single property
      if @object.api.proxy_method_returns_array
        ret[0]
      else
        ret
      end
    end
  end # class ProxyObjectInterface
end
