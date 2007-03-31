# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'thread'

module DBus
  class InterfaceNotInObject < Exception
  end
  class MethodNotInInterface < Exception
  end

  # Exported object type
  class Object
    attr_reader :path, :intfs
    attr_writer :service

    @@intfs = Hash.new
    @@cur_intf = nil
    @@intfs_mutex = Mutex.new

    def initialize(path)
      @path = path
      @intfs = @@intfs.dup
      @service = nil
    end

    def implements(intf)
      @intfs[intf.name] = intf
    end

    def dispatch(msg)
      case msg.message_type
      when Message::METHOD_CALL
        if not @intfs[msg.interface]
          raise InterfaceNotInObject, msg.interface
        end
        p msg
        p @intfs[msg.interface]
        p msg.member.to_sym
        p @intfs[msg.interface].methods.keys
        meth = @intfs[msg.interface].methods[msg.member.to_sym]
        p meth
        raise MethodNotInInterface if not meth
        methname = Object.make_method_name(msg.interface, msg.member)
        retdata = method(methname).call(*msg.params)

        reply = Message.new.reply_to(msg)
        # I'm sure there is a ruby way to do that
        i = 0
        meth.rets.each do |rsig|
          reply.add_param(rsig[1], retdata[i])
        end
        @service.bus.send(reply.marshall)
      end
    end

    def self.dbus_interface(s)
      @@intfs_mutex.synchronize do
        @@cur_intf = @@intfs[s] = Interface.new(s)
        yield
        @@cur_intf = nil
      end
    end

    class UndefinedInterface
    end

    def self.dbus_method(sym, protoype = "", &block)
      raise UndefinedInterface if @@cur_intf.nil?
      puts "dbus_method"
      @@cur_intf.define(Method.new(sym.to_s).from_prototype(protoype))
      p block
      define_method(Object.make_method_name(@@cur_intf.name, sym.to_s), &block) 
      p @@cur_intf.methods
    end

    private
    def self.make_method_name(intfname, methname)
      "#{intfname}%%#{methname}"
    end
  end
end
