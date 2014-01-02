# dbus/introspection.rb - module containing a low-level D-Bus introspection implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'thread'

module DBus
  # Exported object type
  # = Exportable D-Bus object class
  #
  # Objects that are going to be exported by a D-Bus service
  # should inherit from this class. At the client side, use ProxyObject.
  class Object
    # The path of the object.
    attr_reader :path
    # The interfaces that the object supports. Hash: String => Interface
    class_attribute :intfs
    # The service that the object is exported by.
    attr_writer :service

    @@cur_intf = nil            # Interface
    @@intfs_mutex = Mutex.new

    # Create a new object with a given _path_.
    # Use Service#export to export it.
    def initialize(path)
      @path = path
      @service = nil
    end

    # State that the object implements the given _intf_.
    def implements(intf)
      # use a setter
      self.intfs = (self.intfs || {}).merge({intf.name => intf})
    end

    # Dispatch a message _msg_ to call exported methods
    def dispatch(msg)
      case msg.message_type
      when Message::METHOD_CALL
        reply = nil
        begin
          if not self.intfs[msg.interface]
            raise DBus.error("org.freedesktop.DBus.Error.UnknownMethod"),
            "Interface \"#{msg.interface}\" of object \"#{msg.path}\" doesn't exist"
          end
          meth = self.intfs[msg.interface].methods[msg.member.to_sym]
          if not meth
            raise DBus.error("org.freedesktop.DBus.Error.UnknownMethod"),
            "Method \"#{msg.member}\" on interface \"#{msg.interface}\" of object \"#{msg.path}\" doesn't exist"
          end
          methname = Object.make_method_name(msg.interface, msg.member)
          retdata = method(methname).call(*msg.params)
          retdata =  [*retdata]

          reply = Message.method_return(msg)
          meth.rets.zip(retdata).each do |rsig, rdata|
            reply.add_param(rsig.type, rdata)
          end
        rescue => ex
          reply = ErrorMessage.from_exception(ex).reply_to(msg)
        end
        @service.bus.send(reply.marshall)
      end
    end

    # Select (and create) the interface that the following defined methods
    # belong to.
    def self.dbus_interface(s)
      @@intfs_mutex.synchronize do
        unless @@cur_intf = (self.intfs && self.intfs[s])
          @@cur_intf = Interface.new(s)
          self.intfs = (self.intfs || {}).merge({s => @@cur_intf})
        end
        yield
        @@cur_intf = nil
      end
    end

    # Dummy undefined interface class.
    class UndefinedInterface < ScriptError
      def initialize(sym)
        super "No interface specified for #{sym}"
      end
    end

    # Defines an exportable method on the object with the given name _sym_,
    # _prototype_ and the code in a block.
    def self.dbus_method(sym, protoype = "", &block)
      raise UndefinedInterface, sym if @@cur_intf.nil?
      @@cur_intf.define(Method.new(sym.to_s).from_prototype(protoype))
      define_method(Object.make_method_name(@@cur_intf.name, sym.to_s), &block) 
    end

    # Emits a signal from the object with the given _interface_, signal
    # _sig_ and arguments _args_.
    def emit(intf, sig, *args)
      @service.bus.emit(@service, self, intf, sig, *args)
    end

    # Defines a signal for the object with a given name _sym_ and _prototype_.
    def self.dbus_signal(sym, protoype = "")
      raise UndefinedInterface, sym if @@cur_intf.nil?
      cur_intf = @@cur_intf
      signal = Signal.new(sym.to_s).from_prototype(protoype)
      cur_intf.define(Signal.new(sym.to_s).from_prototype(protoype))
      define_method(sym.to_s) do |*args|
        emit(cur_intf, signal, *args)
      end
    end

    ####################################################################
    private

    # Helper method that returns a method name generated from the interface
    # name _intfname_ and method name _methname_.
    def self.make_method_name(intfname, methname)
      "#{intfname}%%#{methname}"
    end
  end # class Object
end # module DBus
