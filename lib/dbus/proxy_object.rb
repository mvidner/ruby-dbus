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
  # Represents a remote object in an external application.
  # Typically, calling a method on an instance of a ProxyObject sends a message
  # over the bus so that the method is executed remotely on the corresponding
  # object.
  class ProxyObject
    # The names of direct subnodes of the object in the tree.
    attr_accessor :subnodes
    # Flag determining whether the object has been introspected.
    # @return [Boolean]
    attr_accessor :introspected
    # The (remote) destination of the object.
    attr_reader :destination
    # The path to the object.
    # @return [ObjectPath]
    attr_reader :path
    # The bus the object is reachable via.
    attr_reader :bus
    # @return [String] The name of the default interface of the object.
    attr_accessor :default_iface
    # @api private
    # @return [ApiOptions]
    attr_reader :api

    OPEN_QUOTE = RUBY_VERSION >= "3.4" ? "'" : "`"

    # Creates a new proxy object living on the given _bus_ at destination _dest_
    # on the given _path_.
    def initialize(bus, dest, path, api: ApiOptions::CURRENT)
      @bus = bus
      @destination = dest
      @path = ObjectPath.new(path)
      @introspected = false
      @interfaces = {}
      @subnodes = []
      @api = api
    end

    # Returns the interfaces of the object.
    # @return [Array<String>] names of the interfaces
    def interfaces
      introspect unless introspected
      @interfaces.keys
    end

    # Retrieves an interface of the proxy object
    # @param [String] intfname
    # @return [ProxyObjectInterface]
    def [](intfname)
      introspect unless introspected
      ifc = @interfaces[intfname]
      raise DBus::Error, "no such interface #{OPEN_QUOTE}#{intfname}' on object #{OPEN_QUOTE}#{@path}'" unless ifc

      ifc
    end

    # Maps the given interface name _intfname_ to the given interface _intf.
    # @param [String] intfname
    # @param [ProxyObjectInterface] intf
    # @return [ProxyObjectInterface]
    # @api private
    def []=(intfname, intf)
      @interfaces[intfname] = intf
    end

    # Introspects the remote object. Allows you to find and select
    # interfaces on the object.
    def introspect
      # Synchronous call here.
      xml = @bus.introspect_data(@destination, @path)
      ProxyObjectFactory.introspect_into(self, xml)
      define_shortcut_methods
      xml
    end

    # For each non duplicated method name in any interface present on the
    # caller, defines a shortcut method dynamically.
    # This function is automatically called when a {ProxyObject} is
    # introspected.
    def define_shortcut_methods
      # builds a list of duplicated methods
      dup_meths = []
      univocal_meths = {}
      @interfaces.each_value do |intf|
        intf.methods.each_value do |meth|
          name = meth.name.to_sym
          # don't overwrite instance methods!
          next if dup_meths.include?(name)
          next if self.class.instance_methods.include?(name)

          if univocal_meths.include? name
            univocal_meths.delete name
            dup_meths << name
          else
            univocal_meths[name] = intf
          end
        end
      end
      univocal_meths.each do |name, intf|
        # creates a shortcut function that forwards each call to the method on
        # the appropriate intf
        singleton_class.class_eval do
          redefine_method name do |*args, &reply_handler|
            intf.method(name).call(*args, &reply_handler)
          end
        end
      end
    end

    # Returns whether the object has an interface with the given _name_.
    def has_iface?(name)
      introspect unless introspected
      @interfaces.key?(name)
    end

    # Registers a handler, the code block, for a signal with the given _name_.
    # It uses _default_iface_ which must have been set.
    # @return [void]
    def on_signal(name, &block)
      unless @default_iface && has_iface?(@default_iface)
        raise NoMethodError, "undefined signal #{OPEN_QUOTE}#{name}' for DBus interface "\
                             "#{OPEN_QUOTE}#{@default_iface}' on object #{OPEN_QUOTE}#{@path}'"
      end

      @interfaces[@default_iface].on_signal(name, &block)
    end

    ####################################################
    private

    # rubocop:disable Lint/MissingSuper
    # as this should forward everything
    #
    # https://github.com/rubocop-hq/ruby-style-guide#no-method-missing
    # and http://blog.marc-andre.ca/2010/11/15/methodmissing-politely/
    # have a point to be investigated

    # Handles all unkown methods, mostly to route method calls to the
    # default interface.
    def method_missing(name, *args, &reply_handler)
      unless @default_iface && has_iface?(@default_iface)
        # TODO: distinguish:
        # - di not specified
        # TODO
        # - di is specified but not found in introspection data
        raise NoMethodError, "undefined method #{OPEN_QUOTE}#{name}' for DBus interface "\
                             "#{OPEN_QUOTE}#{@default_iface}' on object #{OPEN_QUOTE}#{@path}'"
      end

      begin
        @interfaces[@default_iface].method(name).call(*args, &reply_handler)
      rescue NameError => e
        # interesting, foo.method("unknown")
        # raises NameError, not NoMethodError
        raise unless e.to_s =~ /undefined method #{OPEN_QUOTE}#{name}'/

        # BTW e.exception("...") would preserve the class.
        raise NoMethodError, "undefined method #{OPEN_QUOTE}#{name}' for DBus interface "\
                             "#{OPEN_QUOTE}#{@default_iface}' on object #{OPEN_QUOTE}#{@path}'"
      end
    end
    # rubocop:enable Lint/MissingSuper

    def respond_to_missing?(name, _include_private = false)
      @default_iface &&
        has_iface?(@default_iface) &&
        @interfaces[@default_iface].methods.key?(name) or super
    end
  end
end
