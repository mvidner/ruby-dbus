# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'rexml/document'

module DBus
  MethodSignalRE = /^[A-Za-z][A-Za-z0-9_]*$/
  InterfaceElementRE = /^[A-Za-z][A-Za-z0-9_]*$/

  # Exported object type
  class Object
    attr_reader :bus, :path, :intfs

    def initialize(bus, path)
      @bus, @path = bus, path
      @intfs = Hash.new
    end

    def implements(intf)
      @intfs[intf.name] = intf
    end

    def dispatch(msg)
      case msg.message_type
      when Message::METHOD_CALL
        if not @intfs[msg.interface]
          raise InterfaceNotImplemented
        end
        meth = @intfs[msg.interface].methods[msg.member.to_sym]
        raise MethodNotInInterface if not meth
        retdata = method(msg.member).call(*msg.params)

        reply = Message.new.reply_to(msg)
        # I'm sure there is a ruby way to do that
        i = 0
        meth.rets.each do |rsig|
          reply.add_param(rsig[1], retdata[i])
        end
        @bus.send(reply.marshall)
      end
    end
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

    def add(m)
      if m.kind_of?(Method)
        @methods[m.name] = m
      elsif m.kind_of?(Signal)
        @signals[m.name] = m
      end
    end
    alias :<< :add

    # Almost same code as above. Factorize.
    def define_method(id, prototype)
      m = Method.new(id)
      m.from_prototype(prototype)
      add(m)
    end
  end

  # give me a better name please
  class MethSig
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

  class Method < MethSig
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

  class Signal < MethSig
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
          m.add_param(sig)
        else
          raise NotImplementedError, dir
        end
      end
    end

    public
    def parse
      ret = Array.new
      subnodes = Array.new
      t = Time.now
      d = REXML::Document.new(@xml)
      puts @xml
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
    attr_accessor :subnodes
    attr_reader :destination, :path, :bus

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
  end

  class ProxyObjectFactory
    def initialize(xml, bus, dest, path)
      @xml, @bus, @path, @dest = xml, bus, path, dest
    end

    def build
      po = ProxyObject.new(@bus, @dest, @path)

      intfs, po.subnodes = IntrospectXMLParser.new(@xml).parse
      intfs.each do |i|
        poi = ProxyObjectInterface.new(po, i.name)
        i.methods.each_value { |m| poi.define(m) }
        i.signals.each_value { |s| poi.define(s) }
        po[i.name] = poi
      end
      po
    end
  end
end

