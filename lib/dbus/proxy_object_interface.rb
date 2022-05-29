# frozen_string_literal: true

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
    # @return [Hash{String => DBus::Method}]
    attr_reader :methods
    # @return [Hash{String => Signal}]
    attr_reader :signals
    # @return [Hash{Symbol => Property}]
    attr_reader :properties

    # @return [ProxyObject] The proxy object to which this interface belongs.
    attr_reader :object
    # @return [String] The name of the interface.
    attr_reader :name

    # Creates a new proxy interface for the given proxy _object_
    # and the given _name_.
    def initialize(object, name)
      @object = object
      @name = name
      @methods = {}
      @signals = {}
      @properties = {}
    end

    # Returns the string representation of the interface (the name).
    def to_str
      @name
    end

    # Defines a method on the interface from the Method descriptor _method_.
    # @param method [Method]
    def define_method_from_descriptor(method)
      method.params.each do |fpar|
        par = fpar.type
        # This is the signature validity check
        Type::Parser.new(par).parse
      end

      singleton_class.class_eval do
        define_method method.name do |*args, &reply_handler|
          if method.params.size != args.size
            raise ArgumentError, "wrong number of arguments (#{args.size} for #{method.params.size})"
          end

          msg = Message.new(Message::METHOD_CALL)
          msg.path = @object.path
          msg.interface = @name
          msg.destination = @object.destination
          msg.member = method.name
          msg.sender = @object.bus.unique_name
          method.params.each do |fpar|
            par = fpar.type
            msg.add_param(par, args.shift)
          end
          ret = @object.bus.send_sync_or_async(msg, &reply_handler)
          if ret.nil? || @object.api.proxy_method_returns_array
            ret
          else
            method.rets.size == 1 ? ret.first : ret
          end
        end
      end

      @methods[method.name] = method
    end

    # Defines a signal from the descriptor _sig_.
    # @param sig [Signal]
    def define_signal_from_descriptor(sig)
      @signals[sig.name] = sig
    end

    # @param prop [Property]
    def define_property_from_descriptor(prop)
      @properties[prop.name] = prop
    end

    # Defines a signal or method based on the descriptor _ifc_el_.
    # @param ifc_el [DBus::Method,Signal,Property]
    def define(ifc_el)
      case ifc_el
      when Method
        define_method_from_descriptor(ifc_el)
      when Signal
        define_signal_from_descriptor(ifc_el)
      when Property
        define_property_from_descriptor(ifc_el)
      end
    end

    # Defines a proxied method on the interface.
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

    PROPERTY_INTERFACE = "org.freedesktop.DBus.Properties"

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
    # @param property_name [String]
    # @param value [Object]
    def []=(property_name, value)
      property = properties[property_name.to_sym]
      if !property
        raise DBus.error("org.freedesktop.DBus.Error.UnknownProperty"),
              "Property '#{name}.#{property_name}' (on object '#{object.path}') not found"
      end

      case value
      # accommodate former need to explicitly make a variant with the right type
      when Data::Variant
        variant = value
      else
        type = property.type
        typed_value = Data.make_typed(type, value)
        variant = Data::Variant.new(typed_value, member_type: type)
      end

      object[PROPERTY_INTERFACE].Set(name, property_name, variant)
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
  end
end
