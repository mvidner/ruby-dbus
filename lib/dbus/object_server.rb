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
  # The part of a {Connection} that can export {DBus::Object}s to provide
  # services to clients.
  #
  # Note that an ObjectServer does not have a name. Typically a {Connection}
  # has one well known name, but can have none or more.
  #
  # Formerly this class was intermixed with {ProxyService} as Service.
  #
  # @example Usage
  #   bus = DBus.session_bus
  #   obj = DBus::Object.new("/path") # a subclass more likely
  #   bus.object_server.export(obj)
  #   bus.request_name("org.example.Test")
  class ObjectServer < NodeTree
    # @return [Connection] The connection we're using.
    attr_reader :connection

    def initialize(connection)
      @connection = connection
      super()
    end

    # Retrieves an object at the given _path_
    # @param path [ObjectPath]
    # @return [DBus::Object,nil]
    def object(path)
      node = get_node(path, create: false)
      node&.object
    end
    alias [] object

    # Export an object
    # @param obj [DBus::Object]
    # @raise RuntimeError if there's already an exported object at the same path
    def export(obj)
      node = get_node(obj.path, create: true)
      raise "At #{obj.path} there is already an object #{node.object.inspect}" if node.object

      node.object = obj

      obj.object_server = self
      object_manager_for(obj)&.object_added(obj)
    end

    # Undo exporting an object *obj_or_path*.
    # Raises ArgumentError if it is not a DBus::Object.
    # Returns the object, or false if _obj_ was not exported.
    # @param obj_or_path [DBus::Object,ObjectPath,String] an object or a valid object path
    def unexport(obj_or_path)
      path = self.class.path_of(obj_or_path)
      parent_path, _separator, node_name = path.rpartition("/")

      parent_node = get_node(parent_path, create: false)
      return false unless parent_node

      node = if node_name == "" # path == "/"
               parent_node
             else
               parent_node[node_name]
             end
      obj = node&.object
      raise ArgumentError, "Cannot unexport, no object at #{path}" unless obj

      object_manager_for(obj)&.object_removed(obj)
      obj.object_server = nil
      node.object = nil

      # node can be deleted if
      # - it has no children
      # - it is not root
      if node.empty? && !node.equal?(parent_node)
        parent_node.delete(node_name)
      end

      obj
    end

    # Find the (closest) parent of *object*
    # implementing the ObjectManager interface, or nil
    # @return [DBus::Object,nil]
    def object_manager_for(object)
      path = object.path
      node_chain = get_node_chain(path)
      om_node = node_chain.reverse_each.find do |node|
        node.object&.is_a? DBus::ObjectManager
      end
      om_node&.object
    end

    # All objects (not paths) under this path (except itself).
    # @param path [ObjectPath]
    # @return [Array<DBus::Object>]
    # @raise ArgumentError if the *path* does not exist
    def descendants_for(path)
      node = get_node(path, create: false)
      raise ArgumentError, "Object path #{path} doesn't exist" if node.nil?

      node.descendant_objects
    end

    # @param obj_or_path [DBus::Object,ObjectPath,String] an object or a valid object path
    # @return [ObjectPath]
    # @api private
    def self.path_of(obj_or_path)
      case obj_or_path
      when ObjectPath
        obj_or_path
      when String
        ObjectPath.new(obj_or_path)
      when DBus::Object
        obj_or_path.path
      else
        raise ArgumentError, "Expecting a DBus::Object argument or DBus::ObjectPath or String which parses as one"
      end
    end

    #########

    private

    #########

    # @param path [ObjectPath] a path that must exist
    # @return [Array<Node>] nodes from the root to the leaf
    def get_node_chain(path)
      n = @root
      result = [n]
      path.sub(%r{^/}, "").split("/").each do |elem|
        n = n[elem]
        result.push(n)
      end
      result
    end
  end
end
