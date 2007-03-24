require 'rexml/document'

module DBus
  MethodSignalRE = /^[A-Za-z][A-Za-z0-9_]*$/
  InterfaceElementRE = /^[A-Za-z][A-Za-z0-9_]*$/

  class InvalidIntrospectionData < Exception
  end

  # This class is the interface descriptor that comes from the XML we parsed
  # from the Introspect() call
  # It also is the local definition of inerface exported by the program.
  class Interface
    attr_reader :methods, :name
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

    def export_method(id, prototype)
      m = Method.new(methodname)
      prototype.split(/, */) do |arg|
        arg = arg.split(" ")
        raise InvalidClassDefinition if arg.size != 2
        dir, arg = arg
        arg = arg.split(":")
        raise InvalidClassDefinition if arg.size != 2
        name, sig = arg
        if dir == "in"
          m.add_param(name, sig)
        end
      end
      add(m)
    end
  end

  class InterfaceNotImplemented < Exception
  end

  class MethodNotInInterface < Exception
  end

  class MethodNotImplemented < Exception
  end

  class InvalidParameters < Exception
  end

  class Object
    def initialize(connection, path)
      @intfs = Hash.new
    end

    def implements(intf)
      @intfs[intf.name] = intf
    end

    def dispatch(msg)
      case msg.mstgype
      when Message::METHOD_CALL
        if not @intfs[msg.interface]
          raise InterfaceNotImplemented
        end
        meth = @intfs[msg.interface].methods[msg.member]
        raise MethodNotInInterface if not meth
        if meth.signature != msg.signature
          raise InvalidParameters
        end
        method(msg.member).call(*msg.param)
      end
    end
  end

  # give me a better name please
  class MethSig
    attr_reader :name, :params, :rets
    def validate_name(name)
      if (not name =~ MethodSignalRE) or (name.size > 255)
        raise InvalidIntrospectionData
      end
    end

    def initialize(name)
      validate_name(name)
      @name = name
      @params, @rets = Array.new, Array.new
    end

    def add_param(param)
      @params << param
    end

    def add_return(ret)
      @rets << ret
    end
  end

  class Method < MethSig
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
          puts dir
          raise NotImplementedException, dir
        end
      end
    end

    public
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
      p d
      if d > 2
        puts @xml
      end
      [ret, subnodes]
    end
  end

  class ProxyObjectInterface
    attr_accessor :methods
    attr_reader :object, :name

    def initialize(object, name)
      @object, @name = object, name
      @methods = Hash.new
    end

    def to_str
      @name
    end

    def singleton_class
      (class << self ; self ; end)
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
        i.methods.each_value do |m|
          methdef = "def #{m.name}("
          methdef += (0..(m.params.size - 1)).to_a.collect { |n|
            "arg#{n}"
          }.join(", ")
          methdef += %{)
            msg = Message.new(Message::METHOD_CALL)
            msg.path = @object.path
            msg.interface = "#{i.name}"
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
          poi.singleton_class.class_eval(methdef)
          poi.methods[m.name] = m
        end
        po[i.name] = poi
      end
      po
    end
  end
end

