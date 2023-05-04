# frozen_string_literal: true

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

# Our gemspec says rexml is needed and nokogiri is optional
# but in fact either will do

begin
  require "nokogiri"
rescue LoadError
  begin
    require "rexml/document"
  rescue LoadError
    raise LoadError, "cannot load nokogiri OR rexml/document"
  end
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
    # @param xml [String]
    def initialize(xml)
      @xml = xml
    end

    class AbstractXML
      # @!method initialize(xml)
      # @abstract

      # @!method each(xpath)
      # @abstract
      # yields nodes which match xpath of type AbstractXML::Node

      def self.have_nokogiri?
        Object.const_defined?("Nokogiri")
      end

      class Node
        def initialize(node)
          @node = node
        end

        # required methods
        # returns node attribute value
        def [](key); end

        # yields child nodes which match xpath of type AbstractXML::Node
        def each(xpath); end
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
        super()
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
        super()
        @doc = REXML::Document.new(xml)
      end

      def each(path, &block)
        @doc.elements.each(path) { |node| block.call REXMLNode.new(node) }
      end
    end

    @backend = if AbstractXML.have_nokogiri?
                 NokogiriParser
               else
                 REXMLParser
               end

    # @return [Array(Array<Interface>,Array<String>)]
    #   a pair: [list of Interfaces, list of direct subnode names]
    def parse
      # Using a Hash instead of a list helps merge split-up interfaces,
      # a quirk observed in ModemManager (I#41).
      interfaces = Hash.new do |hash, missing_key|
        hash[missing_key] = Interface.new(missing_key)
      end
      subnodes = []
      t = Time.now

      d = IntrospectXMLParser.backend.new(@xml)
      d.each("node/node") do |e|
        subnodes << e["name"]
      end
      d.each("node/interface") do |e|
        i = interfaces[e["name"]]
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
        e.each("property") do |pe|
          p = Property.from_xml(pe)
          i << p
        end
      end
      d = Time.now - t
      if d > 2
        DBus.logger.debug "Some XML took more that two secs to parse. Optimize me!"
      end
      [interfaces.values, subnodes]
    end

    ######################################################################
    private

    # Parses a method signature XML element *elem* and initialises
    # method/signal *methsig*.
    # @param elem [AbstractXML::Node]
    def parse_methsig(elem, methsig)
      elem.each("arg") do |ae|
        name = ae["name"]
        dir = ae["direction"]
        sig = ae["type"]
        case methsig
        when DBus::Signal
          # Direction can only be "out", ignore it
          methsig.add_fparam(name, sig)
        when DBus::Method
          case dir
          # This is a method, so dir defaults to "in"
          when "in", nil
            methsig.add_fparam(name, sig)
          when "out"
            methsig.add_return(name, sig)
          end
        else
          raise NotImplementedError, dir
        end
      end
    end
  end
end
