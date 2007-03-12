require 'rexml/document'

module DBus
  class Interface
    def initialize(name)
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
    attr_reader :name

    def initialize(name)
      @name = name
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
      e.root.elements.each("*/arg") do |ae|
        dir = ae.attributes["direction"]
        sig = ae.attributes["type"]
        case dir
        when "in"
          m.add_param(sig)
        when "out"
          m.add_return(sig)
        else
          raise Exception
        end
      end
    end

    public
    def parse
      ret = Array.new
      d = REXML::Document.new(@xml)
      d.elements.each("node/interface") do |e|
        i = Interface.new(e.attributes["name"])
        e.root.elements.each("*/method") do |me|
          m = Method.new(me.attributes["name"])
          parse_methsig(me, m)
          i << m
        end
        e.root.elements.each("*/signal") do |se|
          s = Signal.new(se.attributes["name"])
          parse_methsig(se, s)
          i << s
        end
        ret << i
      end
      ret
    end
  end
end

