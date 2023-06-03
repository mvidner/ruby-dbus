# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2023 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require_relative "node_tree"

module DBus
  # Used by clients to represent a named service on the other side of the bus.
  #
  # Formerly this class was intermixed with {ObjectServer} as Service.
  #
  # @example Usage
  #   svc = DBus.system_bus["org.freedesktop.machine1"]
  #   manager = svc["/org/freedesktop/machine1"]
  #   p manager.ListImages
  class ProxyService < NodeTree
    # @return [BusName,nil] The service name.
    # Will be nil for a {PeerConnection}
    attr_reader :name
    # @return [Connection] The connection we're using.
    attr_reader :connection

    # @param connection [Connection] The connection we're using.
    def initialize(name, connection)
      @name = BusName.new(name)
      @connection = connection
      super()
    end

    # Determine whether the service name already exists.
    def exists?
      bus = connection # TODO: raise a better error if this is a peer connection
      bus.proxy.ListNames[0].member?(@name)
    end

    # Perform an introspection on all the objects on the service
    # (starting recursively from the root).
    def introspect
      raise NotImplementedError if block_given?

      rec_introspect(@root, "/")
      self
    end

    # Retrieves an object at the given _path_.
    # @param path [ObjectPath]
    # @return [ProxyObject]
    def [](path)
      object(path, api: ApiOptions::A1)
    end

    # Retrieves an object at the given _path_
    # whose methods always return an array.
    # @param path [ObjectPath]
    # @param api [ApiOptions]
    # @return [ProxyObject]
    def object(path, api: ApiOptions::A0)
      node = get_node(path, create: true)
      if node.object.nil? || node.object.api != api
        node.object = ProxyObject.new(
          @connection, @name, path,
          api: api
        )
      end
      node.object
    end

    private

    # Perform a recursive retrospection on the given current _node_
    # on the given _path_.
    def rec_introspect(node, path)
      xml = connection.introspect_data(@name, path)
      intfs, subnodes = IntrospectXMLParser.new(xml).parse
      subnodes.each do |nodename|
        subnode = node[nodename] = Node.new(nodename)
        subpath = if path == "/"
                    "/#{nodename}"
                  else
                    "#{path}/#{nodename}"
                  end
        rec_introspect(subnode, subpath)
      end
      return if intfs.empty?

      node.object = ProxyObjectFactory.new(xml, @connection, @name, path).build
    end
  end

  # A hack for pretending that a {PeerConnection} has a single unnamed {ProxyService}
  # so that we can get {ProxyObject}s from it.
  class ProxyPeerService < ProxyService
    # @param connection [Connection] The peer connection we're using.
    def initialize(connection)
      # this way we disallow ProxyService taking a nil name by accident
      super(":0.0", connection)
      @name = nil
    end
  end
end
