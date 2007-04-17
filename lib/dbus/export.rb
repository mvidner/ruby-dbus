# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# See the file "COPYING" for the exact licensing terms.

require 'thread'

module DBus
  class InterfaceNotInObject < Exception
  end
  class MethodNotInInterface < Exception
  end
  class InvalidReturnType < Exception
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
        meth = @intfs[msg.interface].methods[msg.member.to_sym]
        raise MethodNotInInterface if not meth
        methname = Object.make_method_name(msg.interface, msg.member)
        retdata = method(methname).call(*msg.params)

        reply = Message.new.reply_to(msg)
        # I'm sure there is a ruby way to do that
        i = 0
        if meth.rets.size > 0 and not retdata.kind_of?(Array)
          raise InvalidReturnType
        end
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
      @@cur_intf.define(Method.new(sym.to_s).from_prototype(protoype))
      define_method(Object.make_method_name(@@cur_intf.name, sym.to_s), &block) 
    end

    def emit(intf, sig, *args)
      @service.bus.emit(@service, self, intf, sig, *args)
    end

    def self.dbus_signal(sym, protoype = "")
      raise UndefinedInterface if @@cur_intf.nil?
      cur_intf = @@cur_intf
      signal = Signal.new(sym.to_s).from_prototype(protoype)
      cur_intf.define(Signal.new(sym.to_s).from_prototype(protoype))
      define_method(sym.to_s) do |*args|
        emit(cur_intf, signal, *args)
      end
    end

    private
    def self.make_method_name(intfname, methname)
      "#{intfname}%%#{methname}"
    end
  end
end
