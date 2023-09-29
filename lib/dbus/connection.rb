# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2023 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # D-Bus main connection class
  #
  # Main class that maintains a connection to a bus and can handle incoming
  # and outgoing messages.
  class Connection
    # pop and push messages here
    # @return [MessageQueue]
    attr_reader :message_queue

    # Create a new connection to the bus for a given connect _path_. _path_
    # format is described in the D-Bus specification:
    # http://dbus.freedesktop.org/doc/dbus-specification.html#addresses
    # and is something like:
    # "transport1:key1=value1,key2=value2;transport2:key1=value1,key2=value2"
    # e.g. "unix:path=/tmp/dbus-test" or "tcp:host=localhost,port=2687"
    def initialize(path)
      @message_queue = MessageQueue.new(path)

      # @return [Hash{Integer => Proc}]
      #   key: message serial
      #   value: block to be run when the reply to that message is received
      @method_call_replies = {}

      # @return [Hash{Integer => Message}]
      #   for debugging only: messages for which a reply was not received yet;
      #   key == value.serial
      @method_call_msgs = {}
      @signal_matchrules = {}
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

    # NAME_FLAG_* and REQUEST_NAME_* belong to BusConnection
    # but users will have referenced them in Connection so they need to stay here

    # FIXME: describe the following names, flags and constants.
    # See DBus spec for definition
    NAME_FLAG_ALLOW_REPLACEMENT = 0x1
    NAME_FLAG_REPLACE_EXISTING = 0x2
    NAME_FLAG_DO_NOT_QUEUE = 0x4

    REQUEST_NAME_REPLY_PRIMARY_OWNER = 0x1
    REQUEST_NAME_REPLY_IN_QUEUE = 0x2
    REQUEST_NAME_REPLY_EXISTS = 0x3
    REQUEST_NAME_REPLY_ALREADY_OWNER = 0x4

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
      # @return [Integer] one of
      #   REQUEST_NAME_REPLY_IN_QUEUE
      #   REQUEST_NAME_REPLY_EXISTS
      attr_reader :error_code

      def initialize(error_code)
        @error_code = error_code
        super()
      end
    end

    # In case RequestName did not succeed, raise an exception but first ask the bus who owns the name instead of us
    # @param ret [Integer] what RequestName returned
    # @param name Name that was requested
    # @return [REQUEST_NAME_REPLY_PRIMARY_OWNER,REQUEST_NAME_REPLY_ALREADY_OWNER] on success
    # @raise [NameRequestError] with #error_code REQUEST_NAME_REPLY_EXISTS or REQUEST_NAME_REPLY_IN_QUEUE, on failure
    # @api private
    def handle_return_of_request_name(ret, name)
      if [REQUEST_NAME_REPLY_EXISTS, REQUEST_NAME_REPLY_IN_QUEUE].include?(ret)
        other = proxy.GetNameOwner(name).first
        other_creds = proxy.GetConnectionCredentials(other).first
        message = "Could not request #{name}, already owned by #{other}, #{other_creds.inspect}"
        raise NameRequestError.new(ret), message
      end

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
    # @return [void] actually return whether the rule existed, internal detail
    def add_match(match_rule, &slot)
      # check this is a signal.
      mrs = match_rule.to_s
      DBus.logger.debug "#{@signal_matchrules.size} rules, adding #{mrs.inspect}"
      rule_existed = @signal_matchrules.key?(mrs)
      @signal_matchrules[mrs] = slot
      rule_existed
    end

    # @param match_rule [MatchRule,#to_s]
    # @return [void] actually return whether the rule existed, internal detail
    def remove_match(match_rule)
      mrs = match_rule.to_s
      @signal_matchrules.delete(mrs).nil?
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
  end

  # A {Connection} that is talking directly to a peer, with no bus daemon in between.
  # A prominent example is the PulseAudio connection,
  # see https://www.freedesktop.org/wiki/Software/PulseAudio/Documentation/Developer/Clients/DBus/
  # When starting, it still starts with authentication but omits the Hello message.
  class PeerConnection < Connection
    # Get a {ProxyPeerService}, a dummy helper to get {ProxyObject}s for
    # a {PeerConnection}.
    # @return [ProxyPeerService]
    def peer_service
      ProxyPeerService.new(self)
    end
  end
end
