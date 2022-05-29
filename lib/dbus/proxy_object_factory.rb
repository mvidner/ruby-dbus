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
  # = D-Bus proxy object factory class
  #
  # Class that generates and sets up a proxy object based on introspection data.
  class ProxyObjectFactory
    # Creates a new proxy object factory for the given introspection XML _xml_,
    # _bus_, destination _dest_, and _path_.
    def initialize(xml, bus, dest, path, api: ApiOptions::CURRENT)
      @xml = xml
      @bus = bus
      @path = path
      @dest = dest
      @api = api
    end

    # Investigates the sub-nodes of the proxy object _pobj_ based on the
    # introspection XML data _xml_ and sets them up recursively.
    # @param pobj [ProxyObject]
    # @param xml [String]
    def self.introspect_into(pobj, xml)
      # intfs [Array<Interface>], subnodes [Array<String>]
      intfs, pobj.subnodes = IntrospectXMLParser.new(xml).parse
      intfs.each do |i|
        poi = ProxyObjectInterface.new(pobj, i.name)
        i.methods.each_value { |m| poi.define(m) }
        i.signals.each_value { |s| poi.define(s) }
        i.properties.each_value { |p| poi.define(p) }
        pobj[i.name] = poi
      end
      pobj.introspected = true
    end

    # Generates, sets up and returns the proxy object.
    def build
      po = ProxyObject.new(@bus, @dest, @path, api: @api)
      ProxyObjectFactory.introspect_into(po, @xml)
      po
    end
  end
end
