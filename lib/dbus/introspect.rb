require 'rexml/document'

module DBus
  MethodSignalRE = /^[A-Za-z][A-Za-z0-9_]*$/
  InterfaceElementRE = /^[A-Za-z][A-Za-z0-9_]*$/

  class InvalidIntrospectionData < Exception
  end

  class Interface
    attr_reader :methods, :name
    def validate_name(name)
      raise InvalidIntrospectionData if name.size > 255
      raise InvalidIntrospectionData if name =~ /^\./ or name =~ /\.$/
      raise InvalidIntrospectionData if name =~ /\.\./
      raise InvalidIntrospectionData if not name =~ /\./
      name.split(".").each do |element|
        raise InvalidIntrospectionData if not element =~ InterfaceElementRE
      end
    end

    def initialize(name)
      validate_name(name)
      @name = name
      @methods, @signals = Hash.new, Hash.new
    end

    def <<(m)
      if m.class == Method
        @methods[m.name] = m
      elsif m.class == Signal
        @signals[m.name] = m
      end
    end
  end

  # give me a better name please
  class MethSig
    attr_reader :name, :param
    def validate_name(name)
      if (not name =~ MethodSignalRE) or (name.size > 255)
        raise InvalidIntrospectionData
      end
    end

    def initialize(name)
      validate_name(name)
      @name = name
      @param, @ret = Array.new, Array.new
    end

    def add_param(sig)
      @param << sig
    end

    def add_return(sig)
      @ret << sig
    end
  end

  class Method < MethSig
  end

  class Signal < MethSig
  end

  class XMLParser
    def initialize(xml)
      @xml = xml
    end

    private
    def parse_methsig(e, m)
      e.elements.each("arg") do |ae|
        dir = ae.attributes["direction"]
        sig = ae.attributes["type"]
        case dir
        when "in"
          m.add_param(sig)
        when "out"
          m.add_return(sig)
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
      d = REXML::Document.new(@xml)
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
      ret
    end
  end

  class ProxyObject
    attr_reader :interface
    def initialize(intf, bus, path, dest)
      @interface, @bus, @path, @destination = intf, bus, path, dest
    end

    def singleton_class
      (class << self ; self ; end)
    end
  end

  class ProxyObjectFactory
    def create(xml, bus, path, dest)
      intfs = XMLParser.new(xml).parse
      pos = Hash.new
      intfs.each do |i|
        po = ProxyObject.new(i, bus, path, dest)
        i.methods.each_value do |m|
          methdef = "def #{m.name}("
          methdef += (0..(m.param.size - 1)).to_a.collect { |n|
            "arg#{n}"
          }.join(", ")
          methdef += %{)
            msg = Message.new(Message::METHOD_CALL)
            msg.path = @path
            msg.interface = "#{i.name}"
            msg.destination = @destination
            msg.member = "#{m.name}"
            msg.sender = @bus.unique_name
          }
          idx = 0
          m.param.each do |par|
            #raise NotImplementedException, "sig: #{p}" if p.size > 1

            # There we must check for complex signature and parse accordingly
            # build array and stuff.

            Type::Parser.new(par).parse

            methdef += %{
              msg.add_param("#{par}", arg#{idx})
            }
            idx += 1
          end
          methdef += "
            @bus.send(msg.marshall)
            msg
          end
          "
          po.singleton_class.class_eval(methdef)
          po
        end
        pos[i.name] = po
      end
      pos
    end
  end
end

