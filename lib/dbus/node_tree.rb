# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2023 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # Has a tree of {Node}s, refering to {Object}s or to {ProxyObject}s.
  class NodeTree
    # @return [Node]
    attr_reader :root

    def initialize
      @root = Node.new("/")
    end

    # Get the object node corresponding to the given *path*.
    # @param path [ObjectPath]
    # @param create [Boolean] if true, the the {Node}s in the path are created
    #   if they do not already exist.
    # @return [Node,nil]
    def get_node(path, create: false)
      n = @root
      path.sub(%r{^/}, "").split("/").each do |elem|
        if !(n[elem])
          return nil if !create

          n[elem] = Node.new(elem)
        end
        n = n[elem]
      end
      n
    end
  end

  # = Object path node class
  #
  # Class representing a node on an object path.
  class Node < Hash
    # @return [DBus::Object,DBus::ProxyObject,nil]
    #   The D-Bus object contained by the node.
    attr_accessor :object

    # The name of the node.
    # @return [String] the last component of its object path, or "/"
    attr_reader :name

    # Create a new node with a given _name_.
    def initialize(name)
      super()
      @name = name
      @object = nil
    end

    # Return an XML string representation of the node.
    # It is shallow, not recursing into subnodes
    # @param node_opath [String]
    def to_xml(node_opath)
      xml = '<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
'
      xml += "<node name=\"#{node_opath}\">\n"
      each_key do |k|
        xml += "  <node name=\"#{k}\" />\n"
      end
      @object&.intfs&.each_value do |v|
        xml += v.to_xml
      end
      xml += "</node>"
      xml
    end

    # Return inspect information of the node.
    def inspect
      # Need something here
      "<DBus::Node #{sub_inspect}>"
    end

    # Return instance inspect information, used by Node#inspect.
    def sub_inspect
      s = ""
      if !@object.nil?
        s += format("%x ", @object.object_id)
      end
      contents_sub_inspect = keys
                             .map { |k| "#{k} => #{self[k].sub_inspect}" }
                             .join(",")
      "#{s}{#{contents_sub_inspect}}"
    end

    # All objects (not paths) under this path (except itself).
    # @return [Array<DBus::Object>]
    def descendant_objects
      children_objects = values.map(&:object).compact
      descendants = values.map(&:descendant_objects)
      flat_descendants = descendants.reduce([], &:+)
      children_objects + flat_descendants
    end
  end
end
