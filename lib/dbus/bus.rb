# frozen_string_literal: true

# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "socket"
require "singleton"

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # FIXME: rename Connection to Bus?

  # D-Bus main connection class
  #
  # Main class that maintains a connection to a bus and can handle incoming
  # and outgoing messages.
  class Connection
    # The unique name (by specification) of the message.
    attr_reader :unique_name
    # pop and push messages here
    attr_reader :message_queue

    # Create a new connection to the bus for a given connect _path_. _path_
    # format is described in the D-Bus specification:
    # http://dbus.freedesktop.org/doc/dbus-specification.html#addresses
    # and is something like:
    # "transport1:key1=value1,key2=value2;transport2:key1=value1,key2=value2"
    # e.g. "unix:path=/tmp/dbus-test" or "tcp:host=localhost,port=2687"
    def initialize(path)
      @message_queue = MessageQueue.new(path)
      @unique_name = nil

      # @return [Hash{Integer => Proc}]
      #   key: message serial
      #   value: block to be run when the reply to that message is received
      @method_call_replies = {}

      # @return [Hash{Integer => Message}]
      #   for debugging only: messages for which a reply was not received yet;
      #   key == value.serial
      @method_call_msgs = {}
      @signal_matchrules = {}
      @proxy = nil
    end

    def object_server
      @object_server ||= ObjectServer.new(self)
    end

    # Dispatch all messages that are available in the queue,
    # but do not block on the queue.
    # Called by a main loop when something is available in the queue
    def dispatch_message_queue
      while (msg = @message_queue.pop(blocking: false)) # FIXME: EOFError
        process(msg)
      end
    end

    # Tell a bus to register itself on the glib main loop
    def glibize
      require "glib2"
      # Circumvent a ruby-glib bug
      @channels ||= []

      gio = GLib::IOChannel.new(@message_queue.socket.fileno)
      @channels << gio
      gio.add_watch(GLib::IOChannel::IN) do |_c, _ch|
        dispatch_message_queue
        true
      end
    end

    # FIXME: describe the following names, flags and constants.
    # See DBus spec for definition
    NAME_FLAG_ALLOW_REPLACEMENT = 0x1
    NAME_FLAG_REPLACE_EXISTING = 0x2
    NAME_FLAG_DO_NOT_QUEUE = 0x4

    REQUEST_NAME_REPLY_PRIMARY_OWNER = 0x1
    REQUEST_NAME_REPLY_IN_QUEUE = 0x2
    REQUEST_NAME_REPLY_EXISTS = 0x3
    REQUEST_NAME_REPLY_ALREADY_OWNER = 0x4

    DBUSXMLINTRO = '<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
  <interface name="org.freedesktop.DBus.Introspectable">
    <method name="Introspect">
      <arg direction="out" type="s"/>
    </method>
  </interface>
  <interface name="org.freedesktop.DBus">
    <method name="Hello">
      <arg direction="out" type="s"/>
    </method>
    <method name="RequestName">
      <arg direction="in" type="s"/>
      <arg direction="in" type="u"/>
      <arg direction="out" type="u"/>
    </method>
    <method name="ReleaseName">
      <arg direction="in" type="s"/>
      <arg direction="out" type="u"/>
    </method>
    <method name="StartServiceByName">
      <arg direction="in" type="s"/>
      <arg direction="in" type="u"/>
      <arg direction="out" type="u"/>
    </method>
    <method name="UpdateActivationEnvironment">
      <arg direction="in" type="a{ss}"/>
    </method>
    <method name="NameHasOwner">
      <arg direction="in" type="s"/>
      <arg direction="out" type="b"/>
    </method>
    <method name="ListNames">
      <arg direction="out" type="as"/>
    </method>
    <method name="ListActivatableNames">
      <arg direction="out" type="as"/>
    </method>
    <method name="AddMatch">
      <arg direction="in" type="s"/>
    </method>
    <method name="RemoveMatch">
      <arg direction="in" type="s"/>
    </method>
    <method name="GetNameOwner">
      <arg direction="in" type="s"/>
      <arg direction="out" type="s"/>
    </method>
    <method name="ListQueuedOwners">
      <arg direction="in" type="s"/>
      <arg direction="out" type="as"/>
    </method>
    <method name="GetConnectionUnixUser">
      <arg direction="in" type="s"/>
      <arg direction="out" type="u"/>
    </method>
    <method name="GetConnectionUnixProcessID">
      <arg direction="in" type="s"/>
      <arg direction="out" type="u"/>
    </method>
    <method name="GetAdtAuditSessionData">
      <arg direction="in" type="s"/>
      <arg direction="out" type="ay"/>
    </method>
    <method name="GetConnectionSELinuxSecurityContext">
      <arg direction="in" type="s"/>
      <arg direction="out" type="ay"/>
    </method>
    <method name="ReloadConfig">
    </method>
    <method name="GetId">
      <arg direction="out" type="s"/>
    </method>
    <method name="GetConnectionCredentials">
      <arg direction="in" type="s"/>
      <arg direction="out" type="a{sv}"/>
    </method>
    <property name="Features" type="as" access="read">
      <annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"/>
    </property>
    <property name="Interfaces" type="as" access="read">
      <annotation name="org.freedesktop.DBus.Property.EmitsChangedSignal" value="const"/>
    </property>
    <signal name="NameOwnerChanged">
      <arg type="s"/>
      <arg type="s"/>
      <arg type="s"/>
    </signal>
    <signal name="NameLost">
      <arg type="s"/>
    </signal>
    <signal name="NameAcquired">
      <arg type="s"/>
    </signal>
  </interface>
</node>
'
    # This apostroph is for syntax highlighting editors confused by above xml: "

    # @api private
    # Send a _message_.
    # If _reply_handler_ is not given, wait for the reply
    # and return the reply, or raise the error.
    # If _reply_handler_ is given, it will be called when the reply
    # eventually arrives, with the reply message as the 1st param
    # and its params following
    def send_sync_or_async(message, &reply_handler)
      ret = nil
      if reply_handler.nil?
        send_sync(message) do |rmsg|
          raise rmsg if rmsg.is_a?(Error)

          ret = rmsg.params
        end
      else
        on_return(message) do |rmsg|
          if rmsg.is_a?(Error)
            reply_handler.call(rmsg)
          else
            reply_handler.call(rmsg, * rmsg.params)
          end
        end
        @message_queue.push(message)
      end
      ret
    end

    # @api private
    def introspect_data(dest, path, &reply_handler)
      m = DBus::Message.new(DBus::Message::METHOD_CALL)
      m.path = path
      m.interface = "org.freedesktop.DBus.Introspectable"
      m.destination = dest
      m.member = "Introspect"
      m.sender = unique_name
      if reply_handler.nil?
        send_sync_or_async(m).first
      else
        send_sync_or_async(m) do |*args|
          # TODO: test async introspection, is it used at all?
          args.shift # forget the message, pass only the text
          reply_handler.call(*args)
          nil
        end
      end
    end

    # @api private
    # Issues a call to the org.freedesktop.DBus.Introspectable.Introspect method
    # _dest_ is the service and _path_ the object path you want to introspect
    # If a code block is given, the introspect call in asynchronous. If not
    # data is returned
    #
    # FIXME: link to ProxyObject data definition
    # The returned object is a ProxyObject that has methods you can call to
    # issue somme METHOD_CALL messages, and to setup to receive METHOD_RETURN
    def introspect(dest, path)
      if !block_given?
        # introspect in synchronous !
        data = introspect_data(dest, path)
        pof = DBus::ProxyObjectFactory.new(data, self, dest, path)
        pof.build
      else
        introspect_data(dest, path) do |async_data|
          yield(DBus::ProxyObjectFactory.new(async_data, self, dest, path).build)
        end
      end
    end

    # Exception raised when a service name is requested that is not available.
    class NameRequestError < Exception
    end

    def handle_return_of_request_name(ret, name)
      details = if ret == REQUEST_NAME_REPLY_IN_QUEUE
                  other = proxy.GetNameOwner(name).first
                  other_creds = proxy.GetConnectionCredentials(other).first
                  "already owned by #{other}, #{other_creds.inspect}"
                else
                  "error code #{ret}"
                end
      raise NameRequestError, "Could not request #{name}, #{details}" unless ret == REQUEST_NAME_REPLY_PRIMARY_OWNER

      ret
    end

    # Attempt to request a service _name_.
    # @raise NameRequestError which cannot really be rescued as it will be raised when dispatching a later call.
    # @return [ObjectServer]
    # @deprecated Use {BusConnection#request_name}.
    def request_service(name)
      # Use RequestName, but asynchronously!
      # A synchronous call would not work with service activation, where
      # method calls to be serviced arrive before the reply for RequestName
      # (Ticket#29).
      proxy.RequestName(name, NAME_FLAG_REPLACE_EXISTING) do |rmsg, r|
        # check and report errors first
        raise rmsg if rmsg.is_a?(Error)

        handle_return_of_request_name(r, name)
      end
      object_server
    end

    # Set up a ProxyObject for the bus itself, since the bus is introspectable.
    # @return [ProxyObject] that always returns an array
    #   ({DBus::ApiOptions#proxy_method_returns_array})
    # Returns the object.
    def proxy
      if @proxy.nil?
        path = "/org/freedesktop/DBus"
        dest = "org.freedesktop.DBus"
        pof = DBus::ProxyObjectFactory.new(
          DBUSXMLINTRO, self, dest, path,
          api: ApiOptions::A0
        )
        @proxy = pof.build["org.freedesktop.DBus"]
      end
      @proxy
    end

    # @api private
    # Wait for a message to arrive. Return it once it is available.
    def wait_for_message
      @message_queue.pop # FIXME: EOFError
    end

    # @api private
    # Send a message _msg_ on to the bus. This is done synchronously, thus
    # the call will block until a reply message arrives.
    # @param msg [Message]
    # @param retc [Proc] the reply handler
    # @yieldparam rmsg [MethodReturnMessage] the reply
    # @yieldreturn [Array<Object>] the reply (out) parameters
    def send_sync(msg, &retc) # :yields: reply/return message
      return if msg.nil? # check if somethings wrong

      @message_queue.push(msg)
      @method_call_msgs[msg.serial] = msg
      @method_call_replies[msg.serial] = retc

      retm = wait_for_message
      return if retm.nil? # check if somethings wrong

      process(retm)
      while @method_call_replies.key? msg.serial
        retm = wait_for_message
        process(retm)
      end
    rescue EOFError
      new_err = DBus::Error.new("Connection dropped after we sent #{msg.inspect}")
      raise new_err
    end

    # @api private
    # Specify a code block that has to be executed when a reply for
    # message _msg_ is received.
    # @param msg [Message]
    def on_return(msg, &retc)
      # Have a better exception here
      if msg.message_type != Message::METHOD_CALL
        raise "on_return should only get method_calls"
      end

      @method_call_msgs[msg.serial] = msg
      @method_call_replies[msg.serial] = retc
    end

    # Asks bus to send us messages matching mr, and execute slot when
    # received
    # @param match_rule [MatchRule,#to_s]
    def add_match(match_rule, &slot)
      # check this is a signal.
      mrs = match_rule.to_s
      DBus.logger.debug "#{@signal_matchrules.size} rules, adding #{mrs.inspect}"
      # don't ask for the same match if we override it
      unless @signal_matchrules.key?(mrs)
        DBus.logger.debug "Asked for a new match"
        proxy.AddMatch(mrs)
      end
      @signal_matchrules[mrs] = slot
    end

    # @param match_rule [MatchRule,#to_s]
    def remove_match(match_rule)
      mrs = match_rule.to_s
      rule_existed = @signal_matchrules.delete(mrs).nil?
      # don't remove nonexisting matches.
      return if rule_existed

      # FIXME: if we do try, the Error.MatchRuleNotFound is *not* raised
      # and instead is reported as "no return code for nil"
      proxy.RemoveMatch(mrs)
    end

    # @api private
    # Process a message _msg_ based on its type.
    # @param msg [Message]
    def process(msg)
      return if msg.nil? # check if somethings wrong

      case msg.message_type
      when Message::ERROR, Message::METHOD_RETURN
        raise InvalidPacketException if msg.reply_serial.nil?

        mcs = @method_call_replies[msg.reply_serial]
        if !mcs
          DBus.logger.debug "no return code for mcs: #{mcs.inspect} msg: #{msg.inspect}"
        else
          if msg.message_type == Message::ERROR
            mcs.call(Error.new(msg))
          else
            mcs.call(msg)
          end
          @method_call_replies.delete(msg.reply_serial)
          @method_call_msgs.delete(msg.reply_serial)
        end
      when DBus::Message::METHOD_CALL
        if msg.path == "/org/freedesktop/DBus"
          DBus.logger.debug "Got method call on /org/freedesktop/DBus"
        end
        node = object_server.get_node(msg.path, create: false)
        # introspect a known path even if there is no object on it
        if node &&
           msg.interface == "org.freedesktop.DBus.Introspectable" &&
           msg.member == "Introspect"
          reply = Message.new(Message::METHOD_RETURN).reply_to(msg)
          reply.sender = @unique_name
          xml = node.to_xml(msg.path)
          reply.add_param(Type::STRING, xml)
          @message_queue.push(reply)
        # dispatch for an object
        elsif node&.object
          node.object.dispatch(msg)
        else
          reply = Message.error(msg, "org.freedesktop.DBus.Error.UnknownObject",
                                "Object #{msg.path} doesn't exist")
          @message_queue.push(reply)
        end
      when DBus::Message::SIGNAL
        # the signal can match multiple different rules
        # clone to allow new signale handlers to be registered
        @signal_matchrules.dup.each do |mrs, slot|
          if DBus::MatchRule.new.from_s(mrs).match(msg)
            slot.call(msg)
          end
        end
      else
        # spec(Message Format): Unknown types must be ignored.
        DBus.logger.debug "Unknown message type: #{msg.message_type}"
      end
    rescue Exception => e
      raise msg.annotate_exception(e)
    end

    # Retrieves the Service with the given _name_.
    # @return [Service]
    def service(name)
      # The service might not exist at this time so we cannot really check
      # anything
      ProxyService.new(name, self)
    end
    alias [] service

    # @api private
    # Emit a signal event for the given _service_, object _obj_, interface
    # _intf_ and signal _sig_ with arguments _args_.
    # @param _service unused
    # @param obj [DBus::Object]
    # @param intf [Interface]
    # @param sig [Signal]
    # @param args arguments for the signal
    def emit(_service, obj, intf, sig, *args)
      m = Message.new(DBus::Message::SIGNAL)
      m.path = obj.path
      m.interface = intf.name
      m.member = sig.name
      i = 0
      sig.params.each do |par|
        m.add_param(par.type, args[i])
        i += 1
      end
      @message_queue.push(m)
    end

    ###########################################################################
    private

    # Send a hello messages to the bus to let it know we are here.
    def send_hello
      m = Message.new(DBus::Message::METHOD_CALL)
      m.path = "/org/freedesktop/DBus"
      m.destination = "org.freedesktop.DBus"
      m.interface = "org.freedesktop.DBus"
      m.member = "Hello"
      send_sync(m) do |rmsg|
        @unique_name = rmsg.destination
        DBus.logger.debug "Got hello reply. Our unique_name is #{@unique_name}"
      end
    end
  end

  # A regular Bus {Connection}.
  # As opposed to a peer connection to a single counterparty with no daemon in between.
  # FIXME: move the remaining relevant methods from Connection here, but alias the constants
  class BusConnection < Connection
    # @param name [BusName] the requested name
    # @param flags [Integer] TODO: explain and add a better non-numeric API for this
    # @raise NameRequestError if we could not get the name
    # @example Usage
    #   bus = DBus.session_bus
    #   bus.object_server.export(DBus::Object.new("/org/example/Test"))
    #   bus.request_name("org.example.Test")
    # @see https://dbus.freedesktop.org/doc/dbus-specification.html#bus-messages-request-name
    def request_name(name, flags: 0)
      name = BusName.new(name)
      r = proxy.RequestName(name, flags).first
      handle_return_of_request_name(r, name)
    end
  end

  # = D-Bus session bus class
  #
  # The session bus is a session specific bus (mostly for desktop use).
  #
  # Use SessionBus, the non-singleton ASessionBus is
  # for the test suite.
  class ASessionBus < BusConnection
    # Get the the default session bus.
    def initialize
      super(self.class.session_bus_address)
      send_hello
    end

    def self.session_bus_address
      ENV["DBUS_SESSION_BUS_ADDRESS"] ||
        address_from_file ||
        ("launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET" if Platform.macos?) ||
        (raise NotImplementedError, "Cannot find session bus; sorry, haven't figured out autolaunch yet")
    end

    def self.address_from_file
      # systemd uses /etc/machine-id
      # traditional dbus uses /var/lib/dbus/machine-id
      machine_id_path = Dir["{/etc,/var/lib/dbus,/var/db/dbus}/machine-id"].first
      return nil unless machine_id_path

      machine_id = File.read(machine_id_path).chomp

      display = ENV["DISPLAY"][/:(\d+)\.?/, 1]

      bus_file_path = File.join(ENV["HOME"], "/.dbus/session-bus/#{machine_id}-#{display}")
      return nil unless File.exist?(bus_file_path)

      File.open(bus_file_path).each_line do |line|
        if line =~ /^DBUS_SESSION_BUS_ADDRESS=(.*)/
          address = Regexp.last_match(1)
          return address[/\A'(.*)'\z/, 1] || address[/\A"(.*)"\z/, 1] || address
        end
      end
    end
  end

  # See ASessionBus
  class SessionBus < ASessionBus
    include Singleton
  end

  # Default socket name for the system bus.
  SYSTEM_BUS_ADDRESS = "unix:path=/var/run/dbus/system_bus_socket"

  # = D-Bus system bus class
  #
  # The system bus is a system-wide bus mostly used for global or
  # system usages.
  #
  # Use SystemBus, the non-singleton ASystemBus is
  # for the test suite.
  class ASystemBus < BusConnection
    # Get the default system bus.
    def initialize
      super(self.class.system_bus_address)
      send_hello
    end

    def self.system_bus_address
      ENV["DBUS_SYSTEM_BUS_ADDRESS"] || SYSTEM_BUS_ADDRESS
    end
  end

  # = D-Bus remote (TCP) bus class
  #
  # This class may be used when connecting to remote (listening on a TCP socket)
  # busses. You can also use it to connect to other non-standard path busses.
  #
  # The specified socket_name should look like this:
  # (for TCP)         tcp:host=127.0.0.1,port=2687
  # (for Unix-socket) unix:path=/tmp/my_funky_bus_socket
  #
  # you'll need to take care about authentification then, more info here:
  # https://gitlab.com/pangdudu/ruby-dbus/-/blob/master/README.rdoc
  # TODO: keep the name but update the docs
  class RemoteBus < BusConnection
    # Get the remote bus.
    def initialize(socket_name)
      super(socket_name)
      send_hello
    end
  end

  # See ASystemBus
  class SystemBus < ASystemBus
    include Singleton
  end

  # Shortcut for the {SystemBus} instance
  # @return [Connection]
  def self.system_bus
    SystemBus.instance
  end

  # Shortcut for the {SessionBus} instance
  # @return [Connection]
  def self.session_bus
    SessionBus.instance
  end
end
