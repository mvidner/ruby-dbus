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

require_relative "raw_message"

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # = D-Bus message class
  #
  # Class that holds any type of message that travels over the bus.
  class Message
    # The serial number of the message.
    @@serial = 1
    # Mutex that protects updates on the serial number.
    @@serial_mutex = Mutex.new
    # Type of a message (by specification).
    MESSAGE_SIGNATURE = "yyyyuua(yv)"

    # FIXME: following message type constants should be under Message::Type IMO
    # well, yeah sure
    #
    # Invalid message type.
    INVALID = 0
    # Method call message type.
    METHOD_CALL = 1
    # Method call return value message type.
    METHOD_RETURN = 2
    # Error message type.
    ERROR = 3
    # Signal message type.
    SIGNAL = 4

    # Names used by signal match rules
    TYPE_NAMES = ["invalid", "method_call", "method_return", "error", "signal"].freeze

    # Message flag signyfing that no reply is expected.
    NO_REPLY_EXPECTED = 0x1
    # Message flag signifying that no automatic start is required/must be
    # performed.
    NO_AUTO_START = 0x2

    # The type of the message.
    attr_reader :message_type
    # The path of the object instance the message must be sent to/is sent from.
    attr_accessor :path
    # The interface of the object that must be used/was used.
    attr_accessor :interface
    # The interface member (method/signal name) of the object that must be
    # used/was used.
    attr_accessor :member
    # The name of the error (in case of an error message type).
    attr_accessor :error_name
    # The destination connection of the object that must be used/was used.
    attr_accessor :destination
    # The sender of the message.
    attr_accessor :sender
    # The signature of the message contents.
    attr_accessor :signature
    # @return [Integer] (u32)
    #   The serial number of the message this message is a reply for.
    attr_accessor :reply_serial
    # The protocol.
    attr_reader :protocol
    # @return [Integer] (u32)
    #   The serial of the message.
    attr_reader :serial
    # The parameters of the message.
    attr_reader :params

    # Create a message with message type _mtype_ with default values and a
    # unique serial number.
    def initialize(mtype = INVALID)
      @message_type = mtype

      @flags = 0
      @protocol = 1
      @body_length = 0
      @signature = ""
      @@serial_mutex.synchronize do
        @serial = @@serial
        @@serial += 1
      end
      @params = []
      @destination = nil
      @interface = nil
      @error_name = nil
      @member = nil
      @path = nil
      @reply_serial = nil
      @flags = NO_REPLY_EXPECTED if mtype == METHOD_RETURN
    end

    def to_s
      "#{message_type} sender=#{sender} -> dest=#{destination} " \
      "serial=#{serial} reply_serial=#{reply_serial} " \
      "path=#{path}; interface=#{interface}; member=#{member} " \
      "error_name=#{error_name}"
    end

    # @return [String] name of message type, as used in match rules:
    #    "method_call", "method_return", "signal", "error"
    def message_type_s
      TYPE_NAMES[message_type] || "unknown_type_#{message_type}"
    end

    # Create a regular reply to a message _msg_.
    def self.method_return(msg)
      MethodReturnMessage.new.reply_to(msg)
    end

    # Create an error reply to a message _msg_.
    def self.error(msg, error_name, description = nil)
      ErrorMessage.new(error_name, description).reply_to(msg)
    end

    # Mark this message as a reply to a another message _msg_, taking
    # the serial number of _msg_ as reply serial and the sender of _msg_ as
    # destination.
    def reply_to(msg)
      @reply_serial = msg.serial
      @destination = msg.sender
      self
    end

    # Add a parameter _val_ of type _type_ to the message.
    def add_param(type, val)
      type = type.chr if type.is_a?(Integer)
      @signature += type.to_s
      @params << [type, val]
    end

    # "l" or "B"
    ENDIANNESS_CHAR = ENV.fetch("RUBY_DBUS_ENDIANNESS", HOST_END)
    ENDIANNESS = RawMessage.endianness(ENDIANNESS_CHAR)

    # FIXME: what are these? a message element constant enumeration?
    # See method below, in a message, you have and array of optional parameters
    # that come with an index, to determine their meaning. The values are in
    # spec, more a definition than an enumeration.

    PATH = 1
    INTERFACE = 2
    MEMBER = 3
    ERROR_NAME = 4
    REPLY_SERIAL = 5
    DESTINATION = 6
    SENDER = 7
    SIGNATURE = 8

    RESERVED_PATH = "/org/freedesktop/DBus/Local"

    # Marshall the message with its current set parameters and return
    # it in a packet form.
    # @return [String]
    def marshall
      if @path == RESERVED_PATH
        # the bus would disconnect us, better explain why
        raise "Cannot send a message with the reserved path #{RESERVED_PATH}: #{inspect}"
      end

      params_marshaller = PacketMarshaller.new(endianness: ENDIANNESS)
      @params.each do |type, value|
        params_marshaller.append(type, value)
      end
      @body_length = params_marshaller.packet.bytesize

      marshaller = PacketMarshaller.new(endianness: ENDIANNESS)
      marshaller.append(Type::BYTE, ENDIANNESS_CHAR.ord)
      marshaller.append(Type::BYTE, @message_type)
      marshaller.append(Type::BYTE, @flags)
      marshaller.append(Type::BYTE, @protocol)
      marshaller.append(Type::UINT32, @body_length)
      marshaller.append(Type::UINT32, @serial)

      headers = []
      headers << [PATH,         ["o", @path]]         if @path
      headers << [INTERFACE,    ["s", @interface]]    if @interface
      headers << [MEMBER,       ["s", @member]]       if @member
      headers << [ERROR_NAME,   ["s", @error_name]]   if @error_name
      headers << [REPLY_SERIAL, ["u", @reply_serial]] if @reply_serial
      headers << [DESTINATION,  ["s", @destination]]  if @destination
      #           SENDER is not sent, the message bus fills it in instead
      headers << [SIGNATURE,    ["g", @signature]]    if @signature != ""
      marshaller.append("a(yv)", headers)

      marshaller.align(8)

      marshaller.packet + params_marshaller.packet
    end

    # Unmarshall a packet contained in the buffer _buf_ and set the
    # parameters of the message object according the data found in the
    # buffer.
    # @return [Array(Message,Integer)]
    #   the detected message (self) and
    #   the index pointer of the buffer where the message data ended.
    def unmarshall_buffer(buf)
      pu = PacketUnmarshaller.new(buf, RawMessage.endianness(buf[0]))
      mdata = pu.unmarshall(MESSAGE_SIGNATURE)
      _, @message_type, @flags, @protocol, @body_length, @serial,
        headers = mdata

      headers.each do |struct|
        case struct[0]
        when PATH
          @path = struct[1]
        when INTERFACE
          @interface = struct[1]
        when MEMBER
          @member = struct[1]
        when ERROR_NAME
          @error_name = struct[1]
        when REPLY_SERIAL
          @reply_serial = struct[1]
        when DESTINATION
          @destination = struct[1]
        when SENDER
          @sender = struct[1]
        when SIGNATURE
          @signature = struct[1]
        end
      end
      pu.align_body
      if @body_length.positive? && @signature
        @params = pu.unmarshall(@signature, @body_length)
      end
      [self, pu.consumed_size]
    end

    # Make a new exception from ex, mark it as being caused by this message
    # @api private
    def annotate_exception(exc)
      new_exc = exc.exception("#{exc}; caused by #{self}")
      new_exc.set_backtrace(exc.backtrace)
      new_exc
    end
  end

  class MethodReturnMessage < Message
    def initialize
      super(METHOD_RETURN)
    end
  end

  class ErrorMessage < Message
    def initialize(error_name, description = nil)
      super(ERROR)
      @error_name = error_name
      add_param(Type::STRING, description) unless description.nil?
    end

    def self.from_exception(exc)
      name = if exc.is_a? DBus::Error
               exc.name
             else
               "org.freedesktop.DBus.Error.Failed"
               # exc.class.to_s # RuntimeError is not a valid name, has no dot
             end
      description = exc.message
      msg = new(name, description)
      msg.add_param(DBus.type("as"), exc.backtrace)
      msg
    end
  end
end
