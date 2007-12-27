# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # = InvalidDestinationName class
  # Thrown when you try do send a message to /org/freedesktop/DBus/Local, that
  # is reserved.
  class InvalidDestinationName < Exception
  end

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
    # The serial number of the message this message is a reply for.
    attr_accessor :reply_serial
    # The protocol.
    attr_reader :protocol
    # The serial of the message.
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
      @signature = String.new
      @@serial_mutex.synchronize do
        @serial = @@serial
        @@serial += 1
      end
      @params = Array.new
      @destination = nil
      @error_name = nil
      @member = nil
      @path = nil
      @reply_serial = nil

      if mtype == METHOD_RETURN
        @flags = NO_REPLY_EXPECTED
      end
    end

    # Mark this message as a reply to a another message _m_, taking
    # the serial number of _m_ as reply serial and the sender of _m_ as
    # destination.
    def reply_to(m)
      @message_type = METHOD_RETURN
      @reply_serial = m.serial
      @destination = m.sender
      self
    end

    # Add a parameter _val_ of type _type_ to the message.
    def add_param(type, val)
      type = type.chr if type.kind_of?(Fixnum)
      @signature += type.to_s
      @params << [type, val]
    end

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

    # Marshall the message with its current set parameters and return
    # it in a packet form.
    def marshall
      if @path == "/org/freedesktop/DBus/Local"
        raise InvalidDestinationName
      end

      params = PacketMarshaller.new
      @params.each do |param|
        params.append(param[0], param[1])
      end
      @body_length = params.packet.length

      marshaller = PacketMarshaller.new
      marshaller.append(Type::BYTE, HOST_END)
      marshaller.append(Type::BYTE, @message_type)
      marshaller.append(Type::BYTE, @flags)
      marshaller.append(Type::BYTE, @protocol)
      marshaller.append(Type::UINT32, @body_length)
      marshaller.append(Type::UINT32, @serial)
      marshaller.array(Type::Parser.new("y").parse[0]) do
        if @path
          marshaller.struct do
            marshaller.append(Type::BYTE, PATH)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("o")
            marshaller.append(Type::OBJECT_PATH, @path)
          end
        end
        if @interface
          marshaller.struct do
            marshaller.append(Type::BYTE, INTERFACE)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("s")
            marshaller.append(Type::STRING, @interface)
          end
        end
        if @member
          marshaller.struct do
            marshaller.append(Type::BYTE, MEMBER)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("s")
            marshaller.append(Type::STRING, @member)
          end
        end
        if @error_name
          marshaller.struct do
            marshaller.append(Type::BYTE, ERROR_NAME)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("s")
            marshaller.append(Type::STRING, @error_name)
          end
        end
        if @reply_serial
          marshaller.struct do
            marshaller.append(Type::BYTE, REPLY_SERIAL)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("u")
            marshaller.append(Type::UINT32, @reply_serial)
          end
        end
        if @destination
          marshaller.struct do
            marshaller.append(Type::BYTE, DESTINATION)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("s")
            marshaller.append(Type::STRING, @destination)
          end
        end
        if @signature != ""
          marshaller.struct do
            marshaller.append(Type::BYTE, SIGNATURE)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_simple_string("g")
            marshaller.append(Type::SIGNATURE, @signature)
          end
        end
      end
      marshaller.align(8)
      @params.each do |param|
        marshaller.append(param[0], param[1])
      end
      marshaller.packet
    end

    # Unmarshall a packet contained in the buffer _buf_ and set the
    # parameters of the message object according the data found in the
    # buffer.
    # Return the detected message and the index pointer of the buffer where
    # the message data ended.
    def unmarshall_buffer(buf)
      buf = buf.dup
      if buf[0] == ?l
        endianness = LIL_END
      else
        endianness = BIG_END
      end
      pu = PacketUnmarshaller.new(buf, endianness)
      mdata = pu.unmarshall(MESSAGE_SIGNATURE)
      dummy, @message_type, @flags, @protocol, @body_length, @serial, 
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
      pu.align(8)
      if @body_length > 0 and @signature
        @params = pu.unmarshall(@signature, @body_length)
      end
      [self, pu.idx]
    end # def unmarshall_buf

    # Unmarshall the data of a message found in the buffer _buf_ using
    # Message#unmarshall_buf.
    # Return the message.
    def unmarshall(buf)
      ret, size = unmarshall_buffer(buf)
      ret
    end
  end # class Message

  # A helper exception on errors
  class Error < Exception
    attr_reader :dbus_message
    def initialize(msg)
      super(msg.error_name + ": " + msg.params.join(", "))
      @dbus_message = msg
    end
  end
end # module DBus
