# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
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
  # Regular expressions that should match all method names.
  MethodSignalRE = /^[A-Za-z][A-Za-z0-9_]*$/
  # Regular expressions that should match all interface names.
  InterfaceElementRE = /^[A-Za-z][A-Za-z0-9_]*$/

  # Exception raised when an unknown signal is used.
  class UnknownSignal < Exception
  end

  # Exception raised when an invalid class definition is encountered.
  class InvalidClassDefinition < Exception
  end

  # = D-Bus interface class
  #
  # This class is the interface descriptor.  In most cases, the Introspect()
  # method call instantiates and configures this class for us.
  #
  # It also is the local definition of interface exported by the program.
  # At the client side, see ProxyObjectInterface
  class Interface
    # The name of the interface. String
    attr_reader :name
    # The methods that are part of the interface. Hash: Symbol => DBus::Method
    attr_reader :methods
    # The signals that are part of the interface. Hash: Symbol => Signal
    attr_reader :signals

    # Creates a new interface with a given _name_.
    def initialize(name)
      validate_name(name)
      @name = name
      @methods, @signals = Hash.new, Hash.new
    end

    # Validates a service _name_.
    def validate_name(name)
      raise InvalidIntrospectionData if name.bytesize > 255
      raise InvalidIntrospectionData if name =~ /^\./ or name =~ /\.$/
      raise InvalidIntrospectionData if name =~ /\.\./
      raise InvalidIntrospectionData if not name =~ /\./
      name.split(".").each do |element|
        raise InvalidIntrospectionData if not element =~ InterfaceElementRE
      end
    end

    # Helper method for defining a method _m_.
    def define(m)
      if m.kind_of?(Method)
        @methods[m.name.to_sym] = m
      elsif m.kind_of?(Signal)
        @signals[m.name.to_sym] = m
      end
    end
    alias :<< :define

    # Defines a method with name _id_ and a given _prototype_ in the
    # interface.
    def define_method(id, prototype)
      m = Method.new(id)
      m.from_prototype(prototype)
      define(m)
    end
  end # class Interface

  # = A formal parameter has a name and a type
  class FormalParameter
    attr_reader :name
    attr_reader :type

    def initialize(name, type)
      @name = name
      @type = type
    end

    # backward compatibility, deprecated
    def [](index)
      case index
        when 0 then name
        when 1 then type
        else nil
      end
    end
  end

  # = D-Bus interface element class
  #
  # This is a generic class for entities that are part of the interface
  # such as methods and signals.
  class InterfaceElement
    # The name of the interface element. Symbol
    attr_reader :name
    # The parameters of the interface element. Array: FormalParameter
    attr_reader :params

    # Validates element _name_.
    def validate_name(name)
      if (not name =~ MethodSignalRE) or (name.bytesize > 255)
        raise InvalidMethodName, name
      end
    end

    # Creates a new element with the given _name_.
    def initialize(name)
      validate_name(name.to_s)
      @name = name
      @params = Array.new
    end

    # Adds a formal parameter with _name_ and _signature_
    # (See also Message#add_param which takes signature+value)
    def add_fparam(name, signature)
      @params << FormalParameter.new(name, signature)
    end

    # Deprecated, for backward compatibility
    def add_param(name_signature_pair)
      add_fparam(*name_signature_pair)
    end
  end # class InterfaceElement

  # = D-Bus interface method class
  #
  # This is a class representing methods that are part of an interface.
  class Method < InterfaceElement
    # The list of return values for the method. Array: FormalParameter
    attr_reader :rets

    # Creates a new method interface element with the given _name_.
    def initialize(name)
      super(name)
      @rets = Array.new
    end

    # Add a return value _name_ and _signature_.
    def add_return(name, signature)
      @rets << FormalParameter.new(name, signature)
    end

    # Add parameter types by parsing the given _prototype_.
    def from_prototype(prototype)
      prototype.split(/, */).each do |arg|
        arg = arg.split(" ")
        raise InvalidClassDefinition if arg.size != 2
        dir, arg = arg
        if arg =~ /:/
          arg = arg.split(":")
          name, sig = arg
        else
          sig = arg
        end
        case dir
        when "in"
          add_fparam(name, sig)
        when "out"
          add_return(name, sig)
        end
      end
      self
    end

    # Return an XML string representation of the method interface elment.
    def to_xml
      xml = %{<method name="#{@name}">\n}
      @params.each do |param|
        name = param.name ? %{name="#{param.name}" } : ""
        xml += %{<arg #{name}direction="in" type="#{param.type}"/>\n}
      end
      @rets.each do |param|
        name = param.name ? %{name="#{param.name}" } : ""
        xml += %{<arg #{name}direction="out" type="#{param.type}"/>\n}
      end
      xml += %{</method>\n}
      xml
    end
  end # class Method

  # = D-Bus interface signal class
  #
  # This is a class representing signals that are part of an interface.
  class Signal < InterfaceElement
    # Add parameter types based on the given _prototype_.
    def from_prototype(prototype)
      prototype.split(/, */).each do |arg|
        if arg =~ /:/
          arg = arg.split(":")
          name, sig = arg
        else
          sig = arg
        end
        add_fparam(name, sig)
      end
      self
    end

    # Return an XML string representation of the signal interface elment.
    def to_xml
      xml = %{<signal name="#{@name}">\n}
      @params.each do |param|
        name = param.name ? %{name="#{param.name}" } : ""
        xml += %{<arg #{name}type="#{param.type}"/>\n}
      end
      xml += %{</signal>\n}
      xml
    end
  end # class Signal

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
        puts "Some XML took more that two secs to parse. Optimize me!" if $DEBUG
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
          m.add_fparam(name, sig)
	elsif m.is_a?(DBus::Method)
          case dir
          when "in"
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
      @object, @name = object, name
      @methods, @signals = Hash.new, Hash.new
    end

    # Returns the string representation of the interface (the name).
    def to_str
      @name
    end

    # Returns the singleton class of the interface.
    def singleton_class
      (class << self ; self ; end)
    end

    # FIXME
    def check_for_eval(s)
      raise RuntimeError, "invalid internal data '#{s}'" if not s.to_s =~ /^[A-Za-z0-9_]*$/
    end

    # FIXME
    def check_for_quoted_eval(s)
      raise RuntimeError, "invalid internal data '#{s}'" if not s.to_s =~ /^[^"]+$/
    end

    # Defines a method on the interface from the Method descriptor _m_.
    def define_method_from_descriptor(m)
      check_for_eval(m.name)
      check_for_quoted_eval(@name)
      methdef = "def #{m.name}("
      methdef += (0..(m.params.size - 1)).to_a.collect { |n|
        "arg#{n}"
      }.push("&reply_handler").join(", ")
      methdef += %{)
              msg = Message.new(Message::METHOD_CALL)
              msg.path = @object.path
              msg.interface = "#{@name}"
              msg.destination = @object.destination
              msg.member = "#{m.name}"
              msg.sender = @object.bus.unique_name
            }
      idx = 0
      m.params.each do |fpar|
        par = fpar.type
        check_for_quoted_eval(par)

        # This is the signature validity check
        Type::Parser.new(par).parse

        methdef += %{
          msg.add_param("#{par}", arg#{idx})
        }
        idx += 1
      end
      methdef += "
        @object.bus.send_sync_or_async(msg, &reply_handler)
      end
      "
      singleton_class.class_eval(methdef)
      @methods[m.name] = m
    end

    # Defines a signal from the descriptor _s_.
    def define_signal_from_descriptor(s)
      @signals[s.name] = s
    end

    # Defines a signal or method based on the descriptor _m_.
    def define(m)
      if m.kind_of?(Method)
        define_method_from_descriptor(m)
      elsif m.kind_of?(Signal)
        define_signal_from_descriptor(m)
      end
    end

    # Defines a proxied method on the interface.
    def define_method(methodname, prototype)
      m = Method.new(methodname)
      m.from_prototype(prototype)
      define(m)
    end

    # Registers a handler (code block) for a signal with _name_ arriving
    # over the given _bus_. If no block is given, the signal is unregistered.
    def on_signal(bus, name, &block)
      mr = DBus::MatchRule.new.from_signal(self, name)
      if block.nil?
        bus.remove_match(mr)
      else
        bus.add_match(mr) { |msg| block.call(*msg.params) }
      end
    end

    PROPERTY_INTERFACE = "org.freedesktop.DBus.Properties"

    # Read a property.
    def [](propname)
      self.object[PROPERTY_INTERFACE].Get(self.name, propname)[0]
    end

    # Write a property.
    def []=(propname, value)
      self.object[PROPERTY_INTERFACE].Set(self.name, propname, value)
    end

    # Read all properties at once, as a hash.
    def all_properties
      self.object[PROPERTY_INTERFACE].GetAll(self.name)[0]
    end
  end # class ProxyObjectInterface

  # D-Bus proxy object class
  #
  # Class representing a remote object in an external application.
  # Typically, calling a method on an instance of a ProxyObject sends a message
  # over the bus so that the method is executed remotely on the correctponding
  # object.
  class ProxyObject
    # The names of direct subnodes of the object in the tree.
    attr_accessor :subnodes
    # Flag determining whether the object has been introspected.
    attr_accessor :introspected
    # The (remote) destination of the object.
    attr_reader :destination
    # The path to the object.
    attr_reader :path
    # The bus the object is reachable via.
    attr_reader :bus
    # The default interface of the object, as String.
    attr_accessor :default_iface

    # Creates a new proxy object living on the given _bus_ at destination _dest_
    # on the given _path_.
    def initialize(bus, dest, path)
      @bus, @destination, @path = bus, dest, path
      @interfaces = Hash.new
      @subnodes = Array.new
    end

    # Returns the interfaces of the object.
    def interfaces
      @interfaces.keys
    end

    # Retrieves an interface of the proxy object (ProxyObjectInterface instance).
    def [](intfname)
      @interfaces[intfname]
    end

    # Maps the given interface name _intfname_ to the given interface _intf.
    def []=(intfname, intf)
      @interfaces[intfname] = intf
    end

    # Introspects the remote object.  Allows you to find and select
    # interfaces on the object.
    def introspect
      # Synchronous call here.
      xml = @bus.introspect_data(@destination, @path)
      ProxyObjectFactory.introspect_into(self, xml)
      xml
    end

    # Returns whether the object has an interface with the given _name_.
    def has_iface?(name)
      raise "Cannot call has_iface? if not introspected" if not @introspected
      @interfaces.member?(name)
    end

    # Registers a handler, the code block, for a signal with the given _name_.
    # It uses _default_iface_ which must have been set.
    def on_signal(name, &block)
      if @default_iface and has_iface?(@default_iface)
        @interfaces[@default_iface].on_signal(@bus, name, &block)
      else
        # TODO improve
        raise NoMethodError
      end
    end

    ####################################################
    private

    # Handles all unkown methods, mostly to route method calls to the
    # default interface.
    def method_missing(name, *args, &reply_handler)
      if @default_iface and has_iface?(@default_iface)
        begin
          @interfaces[@default_iface].method(name).call(*args, &reply_handler)
        rescue NameError => e
          # interesting, foo.method("unknown")
          # raises NameError, not NoMethodError
          raise unless e.to_s =~ /undefined method `#{name}'/
          # BTW e.exception("...") would preserve the class.
          raise NoMethodError,"undefined method `#{name}' for DBus interface `#{@default_iface}' on object `#{@path}'"
        end
      else
        # TODO distinguish:
        # - di not specified
        #TODO
        # - di is specified but not found in introspection data
        raise NoMethodError, "undefined method `#{name}' for DBus interface `#{@default_iface}' on object `#{@path}'"
      end
    end
  end # class ProxyObject

  # = D-Bus proxy object factory class
  #
  # Class that generates and sets up a proxy object based on introspection data.
  class ProxyObjectFactory
    # Creates a new proxy object factory for the given introspection XML _xml_,
    # _bus_, destination _dest_, and _path_.
    def initialize(xml, bus, dest, path)
      @xml, @bus, @path, @dest = xml, bus, path, dest
    end

    # Investigates the sub-nodes of the proxy object _po_ based on the
    # introspection XML data _xml_ and sets them up recursively.
    def ProxyObjectFactory.introspect_into(po, xml)
      intfs, po.subnodes = IntrospectXMLParser.new(xml).parse
      intfs.each do |i|
        poi = ProxyObjectInterface.new(po, i.name)
        i.methods.each_value { |m| poi.define(m) }
        i.signals.each_value { |s| poi.define(s) }
        po[i.name] = poi
      end
      po.introspected = true
    end

    # Generates, sets up and returns the proxy object.
    def build
      po = ProxyObject.new(@bus, @dest, @path)
      ProxyObjectFactory.introspect_into(po, @xml)
      po
    end
  end # class ProxyObjectFactory
end # module DBus

