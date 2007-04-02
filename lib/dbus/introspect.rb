# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'rexml/document'

module DBus
  MethodSignalRE = /^[A-Za-z][A-Za-z0-9_]*$/
  InterfaceElementRE = /^[A-Za-z][A-Za-z0-9_]*$/

  class UnknownSignal
  end

  # = D-Bus interface class
  #
  # This class is the interface descriptor that comes from the XML we
  # parsed from the Introspect() call.
  # It also is the local definition of inerface exported by the program.
  class Interface
    attr_reader :name, :methods, :signals

    def initialize(name)
      validate_name(name)
      @name = name
      @methods, @signals = Hash.new, Hash.new
    end

    def validate_name(name)
      raise InvalidIntrospectionData if name.size > 255
      raise InvalidIntrospectionData if name =~ /^\./ or name =~ /\.$/
      raise InvalidIntrospectionData if name =~ /\.\./
      raise InvalidIntrospectionData if not name =~ /\./
      name.split(".").each do |element|
        raise InvalidIntrospectionData if not element =~ InterfaceElementRE
      end
    end

    def define(m)
      if m.kind_of?(Method)
        @methods[m.name.to_sym] = m
      elsif m.kind_of?(Signal)
        @signals[m.name.to_sym] = m
      end
    end
    alias :<< :define

    # Almost same code as above. Factorize.
    def define_method(id, prototype)
      m = Method.new(id)
      m.from_prototype(prototype)
      define(m)
    end
  end

  # give me a better name please
  class InterfaceElement
    attr_reader :name, :params
    def validate_name(name)
      if (not name =~ MethodSignalRE) or (name.size > 255)
        raise InvalidMethodName
      end
    end

    def initialize(name)
      validate_name(name.to_s)
      @name = name
      @params = Array.new
    end

    def add_param(param)
      @params << param
    end
  end

  class Method < InterfaceElement
    attr_reader :rets

    def initialize(name)
      super(name)
      @rets = Array.new
    end

    def add_return(ret)
      @rets << ret
    end

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
  end

  class Signal < InterfaceElement
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

    def to_xml
      xml = %{<signal name="#{@name}">\n}
      @params.each do |param|
        name = param[0] ? %{name="#{param[0]}" } : ""
        xml += %{<arg #{name}type="#{param[1]}"/>\n}
      end
      xml += %{</signal>\n}
      xml
    end
  end

  class IntrospectXMLParser
    def initialize(xml)
      @xml = xml
    end

    private
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

    public
    def parse_subnodes
      subnodes = Array.new
      t = Time.now
      d = REXML::Document.new(@xml)
      d.elements.each("node/node") do |e|
        subnodes << e.attributes["name"]
      end
      subnodes
    end

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
        puts "Some XML took more that two secs to parse. Optimize me!"
      end
      [ret, subnodes]
    end
  end

  class ProxyObjectInterface
    attr_accessor :methods, :signals
    attr_reader :object, :name

    def initialize(object, name)
      @object, @name = object, name
      @methods, @signals = Hash.new, Hash.new
    end

    def to_str
      @name
    end

    def singleton_class
      (class << self ; self ; end)
    end

    def define_method_from_descriptor(m)
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
            yield(rmsg, *rmsg.params)
          end
          @object.bus.send(msg.marshall)
        else
          @object.bus.send_sync(msg) do |rmsg|
            ret = rmsg.params
          end
        end
        ret
      end
      "
      singleton_class.class_eval(methdef)
      @methods[m.name] = m
    end

    def define_signal_from_descriptor(s)
      @signals[s.name] = s
    end

    def define(m)
      if m.kind_of?(Method)
        define_method_from_descriptor(m)
      elsif m.kind_of?(Signal)
        define_signal_from_descriptor(m)
      end
    end

    def define_method(methodname, prototype)
      m = Method.new(methodname)
      m.from_prototype(prototype)
      define(m)
    end
  end

  class ProxyObject
    attr_accessor :subnodes, :introspected
    attr_reader :destination, :path, :bus
    attr_accessor :default_iface

    def initialize(bus, dest, path)
      @bus, @destination, @path = bus, dest, path
      @interfaces = Hash.new
      @subnodes = Array.new
    end

    def interfaces
      @interfaces.keys
    end

    def [](intfname)
      @interfaces[intfname]
    end

    def []=(intfname, intf)
      @interfaces[intfname] = intf
    end

    def introspect
      # Synchronous call here
      xml = @bus.introspect_data(@destination, @path)
      ProxyObjectFactory.introspect_into(self, xml)
    end

    def has_iface?(name)
      raise "Cannot call has_iface? is not introspected" if not @introspected
      @interfaces.member?(name)
    end

    def on_signal(name, &block)
      if @default_iface and has_iface?(@default_iface)
        intf = @interfaces[@default_iface]
        signal = intf.signals[name]
        raise UnknownSignal if signal.nil?
        mr = DBus::MatchRule.new.from_signal(intf, signal)
        bus.add_match(mr) { |msg| block.call(*msg.params) }
      else
        raise NoMethodError
      end
    end

    def method_missing(name, *args)
      if @default_iface and has_iface?(@default_iface)
        @interfaces[@default_iface].method(name).call(*args)
      else
        raise NoMethodError
      end
    end
  end

  class ProxyObjectFactory
    def initialize(xml, bus, dest, path)
      @xml, @bus, @path, @dest = xml, bus, path, dest
    end

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

    def build
      po = ProxyObject.new(@bus, @dest, @path)
      ProxyObjectFactory.introspect_into(po, @xml)
      po
    end
  end
end

