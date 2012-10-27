# dbus/xml.rb - introspection parser, rexml/nokogiri abstraction
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2012 Geoff Youngs
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

# TODO check if it is slow, make replaceable
require 'rexml/document'
begin
require 'nokogiri'
rescue LoadError
end

module DBus
  # = D-Bus introspect XML parser class
  #
  # This class parses introspection XML of an object and constructs a tree
  # of Node, Interface, Method, Signal instances.
  class IntrospectXMLParser
    class << self
      attr_accessor :backend
    end
    # Creates a new parser for XML data in string _xml_.
    def initialize(xml)
      @xml = xml
    end

    class AbstractXML
      def self.have_nokogiri?
        Object.const_defined?('Nokogiri')
      end
      class Node
        def initialize(node)
          @node = node
        end
        # required methods
        # returns node attribute value
        def [](key)
        end
        # yields child nodes which match xpath of type AbstractXML::Node
        def each(xpath)
        end
      end
      # required methods
      # initialize parser with xml string
      def initialize(xml)
      end
      # yields nodes which match xpath of type AbstractXML::Node
      def each(xpath)
      end
    end

    class NokogiriParser < AbstractXML
      class NokogiriNode < AbstractXML::Node
        def [](key)
          @node[key]
        end
        def each(path, &block)
          @node.search(path).each { |node| block.call NokogiriNode.new(node) }
        end
      end
      def initialize(xml)
        @doc = Nokogiri.XML(xml)
      end
      def each(path, &block)
        @doc.search("//#{path}").each { |node| block.call NokogiriNode.new(node) }
      end
    end

    class REXMLParser < AbstractXML
      class REXMLNode < AbstractXML::Node
        def [](key)
          @node.attributes[key]
        end
        def each(path, &block)
          @node.elements.each(path) { |node| block.call REXMLNode.new(node) }
        end
      end
      def initialize(xml)
        @doc = REXML::Document.new(xml)
      end
      def each(path, &block)
        @doc.elements.each(path) { |node| block.call REXMLNode.new(node) }
      end
    end

    if AbstractXML.have_nokogiri?
      @backend = NokogiriParser
    else
      @backend = REXMLParser
    end

    # return a pair: [list of Interfaces, list of direct subnode names]
    def parse
      interfaces = Array.new
      subnodes = Array.new
      t = Time.now


      d = IntrospectXMLParser.backend.new(@xml)
      d.each("node/node") do |e|
        subnodes << e["name"]
      end
      d.each("node/interface") do |e|
        i = Interface.new(e["name"])
        e.each("method") do |me|
          m = Method.new(me["name"])
          parse_methsig(me, m)
          i << m
        end
        e.each("signal") do |se|
          s = Signal.new(se["name"])
          parse_methsig(se, s)
          i << s
        end
        interfaces << i
      end
      d = Time.now - t
      if d > 2
        DBus.logger.debug "Some XML took more that two secs to parse. Optimize me!"
      end
      [interfaces, subnodes]
    end

    ######################################################################
    private

    # Parses a method signature XML element _e_ and initialises
    # method/signal _m_.
    def parse_methsig(e, m)
      e.each("arg") do |ae|
        name = ae["name"]
        dir = ae["direction"]
        sig = ae["type"]
	if m.is_a?(DBus::Signal)
          # Direction can only be "out", ignore it
          m.add_fparam(name, sig)
	elsif m.is_a?(DBus::Method)
          case dir
          # This is a method, so dir defaults to "in"
          when "in", nil
            m.add_fparam(name, sig)
          when "out"
	    m.add_return(name, sig)
	  end
        else
          raise NotImplementedError, dir
        end
      end
    end
  end # class IntrospectXMLParser
end # module DBus

