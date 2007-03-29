# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

module DBus
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
end

