# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'rexml/document'

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
  # method call instanciates and configures this class for us.
  #
  # It also is the local definition of interface exported by the program.
  class Interface
    # The name of the interface.
    attr_reader :name
    # The methods that are part of the interface.
    attr_reader :methods
    # The signals that are part of the interface.
    attr_reader :signals

    # Creates a new interface with a given _name_.
    def initialize(name)
      validate_name(name)
      @name = name
      @methods, @signals = Hash.new, Hash.new
    end

    # Validates a service _name_.
    def validate_name(name)
      raise InvalidIntrospectionData if name.size > 255
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

  # = D-Bus interface element class
  #
  # This is a generic class for entities that are part of the interface
  # such as methods and signals.
  class InterfaceElement
    # The name of the interface element.
    attr_reader :name
    # The parameters of the interface element
    attr_reader :params

    # Validates element _name_.
    def validate_name(name)
      if (not name =~ MethodSignalRE) or (name.size > 255)
        raise InvalidMethodName
      end
    end

    # Creates a new element with the given _name_.
    def initialize(name)
      validate_name(name.to_s)
      @name = name
      @params = Array.new
    end

    # Adds a parameter _param_.
    def add_param(param)
      @params << param
    end
  end # class InterfaceElement

  # = D-Bus interface method class
  #
  # This is a class representing methods that are part of an interface.
  class Method < InterfaceElement
    # The list of return values for the method.
    attr_reader :rets

    # Creates a new method interface element with the given _name_.
    def initialize(name)
      super(name)
      @rets = Array.new
    end

    # Add a return value _ret_.
    def add_return(ret)
      @rets << ret
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
          add_param([name, sig])
        when "out"
          add_return([name, sig])
        end
      end
      self
    end

    # Return an XML string representation of the method interface elment.
    def to_xml
      xml = %{<method name="#{@name}">\n}
      @params.each do |param|
        name = param[0] ? %{name="#{param[0]}" } : ""
        xml += %{<arg #{name}direction="in" type="#{param[1]}"/>\n}
      end
      @rets.each do |param|
        name = param[0] ? %{name="#{param[0]}" } : ""
        xml += %{<arg #{name}direction="out" type="#{param[1]}"/>\n}
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
        add_param([name, sig])
      end
      self
    end

    # Return an XML string representation of the signal interface elment.
    def to_xml
      xml = %{<signal name="#{@name}">\n}
      @params.each do |param|
        name = param[0] ? %{name="#{param[0]}" } : ""
        xml += %{<arg #{name}type="#{param[1]}"/>\n}
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
    # Creates a new parser for XML data in string _xml_.
    def initialize(xml)
      @xml = xml
    end

    # Recursively parses the subnodes, constructing the tree.
    def parse_subnodes
      subnodes = Array.new
      t = Time.now
      d = REXML::Document.new(@xml)
      d.elements.each("node/node") do |e|
        subnodes << e.attributes["name"]
      end
      subnodes
    end

    # Parses the XML, constructing the tree.
    def parse
      ret = Array.new
      subnodes = Array.new
      t = Time.now
      d = REXML::Document.new(@xml)
      d.elements.each("node/node") do |e|
        subnodes << e.attributes["name"]
      end
      d.elements.each("node/interface") do |e|
        i = Interface.new(e.attributes["name"])
        e.elements.each("method") do |me|
          m = Method.new(me.attributes["name"])
          parse_methsig(me, m)
          i << m
        end
        e.elements.each("signal") do |se|
          s = Signal.new(se.attributes["name"])
          parse_methsig(se, s)
          i << s
        end
        ret << i
      end
      d = Time.now - t
      if d > 2
        puts "Some XML took more that two secs to parse. Optimize me!" if $DEBUG
      end
      [ret, subnodes]
    end

    ######################################################################
    private

    # Parses a method signature XML element _e_ and initialises
    # method _m_.
    def parse_methsig(e, m)
      e.elements.each("arg") do |ae|
        name = ae.attributes["name"]
        dir = ae.attributes["direction"]
        sig = ae.attributes["type"]
        case dir
        when "in"
          m.add_param([name, sig])
        when "out"
          m.add_return([name, sig])
        when nil # It's a signal, no direction
          m.add_param([name, sig])
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
      raise RuntimeException, "invalid internal data" if not s.to_s =~ /^[A-Za-z0-9_]*$/
    end

    # FIXME
    def check_for_quoted_eval(s)
      raise RuntimeException, "invalid internal data" if not s.to_s =~ /^[^"]+$/
    end

    # Defines a method on the interface from the descriptor _m_.
    def define_method_from_descriptor(m)
      check_for_eval(m.name)
      check_for_quoted_eval(@name)
      methdef = "def #{m.name}("
      methdef += (0..(m.params.size - 1)).to_a.collect { |n|
        "arg#{n}"
      }.join(", ")
      methdef += %{)
              msg = Message.new(Message::METHOD_CALL)
              msg.path = @object.path
              msg.interface = "#{@name}"
              msg.destination = @object.destination
              msg.member = "#{m.name}"
              msg.sender = @object.bus.unique_name
            }
      idx = 0
      m.params.each do |npar|
        paramname, par = npar
        check_for_quoted_eval(par)

        # This is the signature validity check
        Type::Parser.new(par).parse

        methdef += %{
          msg.add_param("#{par}", arg#{idx})
        }
        idx += 1
      end
      methdef += "
        ret = nil
        if block_given?
          @object.bus.on_return(msg) do |rmsg|
            if rmsg.is_a?(Error)
              yield(rmsg)
            else
              yield(rmsg, *rmsg.params)
            end
          end
          @object.bus.send(msg.marshall)
        else
          @object.bus.send_sync(msg) do |rmsg|
            if rmsg.is_a?(Error)
              raise rmsg
            else
              ret = rmsg.params
            end
          end
        end
        ret
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
    # over the given _bus_.
    def on_signal(bus, name, &block)
      mr = DBus::MatchRule.new.from_signal(self, name)
      bus.add_match(mr) { |msg| block.call(*msg.params) }
    end
  end # class ProxyObjectInterface

  # D-Bus proxy object class
  #
  # Class representing a remote object in an external application.
  # Typically, calling a method on an instance of a ProxyObject sends a message
  # over the bus so that the method is executed remotely on the correctponding
  # object.
  class ProxyObject
    # The subnodes of the object in the tree.
    attr_accessor :subnodes
    # Flag determining whether the object has been introspected.
    attr_accessor :introspected
    # The (remote) destination of the object.
    attr_reader :destination
    # The path to the object.
    attr_reader :path
    # The bus the object is reachable via.
    attr_reader :bus
    # The default interface of the object.
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
      raise "Cannot call has_iface? is not introspected" if not @introspected
      @interfaces.member?(name)
    end

    # Registers a handler, the code block, for a signal with the given _name_.
    def on_signal(name, &block)
      if @default_iface and has_iface?(@default_iface)
        @interfaces[@default_iface].on_signal(@bus, name, &block)
      else
        raise NoMethodError
      end
    end

    ####################################################
    private

    # Handles all unkown methods, mostly to route method calls to the
    # default interface.
    def method_missing(name, *args)
      if @default_iface and has_iface?(@default_iface)
        @interfaces[@default_iface].method(name).call(*args)
      else
        raise NoMethodError
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

