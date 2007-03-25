# dbus.rb - Module containing the low-level D-Bus implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'dbus/type'
require 'dbus/introspect'

require 'socket'
require 'thread'

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # Default socket name for the system bus.
  SystemSocketName = "unix=/var/run/dbus/system_bus_socket"

  # Byte signifying big endianness.
  BIG_END = ?B
  # Byte signifying little endianness.
  LIL_END = ?l

  if [0x01020304].pack("L").unpack("V")[0] == 0x01020304
    # Flag signifying that the host is little endian.
    HOST_END = LIL_END
  else
    # Flag signifying that the host is big endian.
    HOST_END = BIG_END
  end

  # Exception raised when an invalid packet is encountered.
  class InvalidPacketException < Exception
  end

  # Exception raised when there is a problem with a type (may be unknown or mismatch).
  class TypeException < Exception
  end

  # Exception raised when there is a part not (yet) implemented.
  #
  # FIXME: isn't there a Ruby core NotImplementedError exception already?
  class NotImplementedException < Exception
  end

  # = D-Bus packet unmarshaller class
  #
  # Class that handles the conversion (unmarshalling) of payload data
  # to Ruby objects.
  class IncompleteBufferException < Exception
  end

  class PacketUnmarshaller
    # Index pointer that points to the byte in the data that is 
    # currently being processed.
    #
    # FIXME: @idx seems to be an internal ivar, is it ever accessed from
    # the outside?
    attr_reader :idx

    # Create a new unmarshaller for the given data _buffer_ and _endianness_.
    def initialize(buffer, endianness)
      @buffy, @endianness = buffer.dup, endianness
      if @endianness == BIG_END
        @uint32 = "N"
        @uint16 = "n"
      elsif @endianness == LIL_END
        @uint32 = "V"
        @uint16 = "v"
      else
        # FIXME: shouldn't a more special exception be raised here?
        raise Exception, "Incorrect endianneess"
      end
      @idx = 0
    end

    # Unmarshall the buffer for a given _signature_ and length _len_.
    # Return an array of unmashalled (Ruby) objects.
    def unmarshall(signature, len = nil)
      if len != nil
        if @buffy.size < @idx + len
          raise IncompleteBufferException
        end
      end
      sigtree = Type::Parser.new(signature).parse
      ret = Array.new
      sigtree.each do |elem|
        ret << do_parse(elem)
      end
      ret
    end

    # Align the pointer index on a 2 byte index.
    def align2
      @idx = @idx + 1 & ~1
      raise IncompleteBufferException if @idx > @buffy.size
    end

    # Align the pointer index on a 4 byte index.
    def align4
      @idx = @idx + 3 & ~3
      raise IncompleteBufferException if @idx > @buffy.size
    end

    # Align the pointer index on a 8 byte index.
    def align8
      @idx = @idx + 7 & ~7
      raise IncompleteBufferException if @idx > @buffy.size
    end

    # Align the pointer index on a byte index of _a_, where a
    # must be 1, 2, 4 or 8.
    def align(a)
      # FIXME: not replaceable (and the previous 3 methods by)?? ->
      # when 1
      # when 2, 4, 8
      #   @idx = @idx + (a - 1) & ~(a - 1)
      #   raise ...
      # else
      #   raise
      # end
      case a
      when 1
      when 2
        align2
      when 4
        align4
      when 8
        align8
      else
        raise "Unsupported alignment #{a}"
      end
    end

    ###############################################################
    # FIXME: does anyone except the object itself call the above methods?
    private

    # Retrieve the next _nbytes_ number of bytes from the buffer.
    def get(nbytes)
      raise IncompleteBufferException if @idx + nbytes > @buffy.size
      ret = @buffy.slice(@idx, nbytes)
      @idx += nbytes
      ret
    end

    # Retrieve the series of bytes until the next NULL (\0) byte.
    def get_nul_terminated
      raise IncompleteBufferException if not @buffy[@idx..-1] =~ /^([^\0]*)\0/
      str = $1
      raise IncompleteBufferException if @idx + str.size + 1 > @buffy.size
      @idx += str.size + 1
      str
    end

    # Get the string length and string itself from the buffer.
    # Return the string.
    #
    # FIXME: should be called get_string
    def getstring
      align4
      str_sz = get(4).unpack(@uint32)[0]
      ret = @buffy.slice(@idx, str_sz)
      raise IncompleteBufferException if @idx + str_sz + 1 > @buffy.size
      @idx += str_sz
      if @buffy[@idx] != 0
        raise InvalidPacketException, "String is not nul-terminated"
      end
      @idx += 1
      # no exception, see check above
      ret
    end

    # Get the signature length and signature itself from the buffer.
    # Return the signature.
    #
    # FIXME: should be called get_signature
    def getsignature
      str_sz = get(1).unpack('C')[0]
      ret = @buffy.slice(@idx, str_sz)
      raise IncompleteBufferException if @idx + str_sz + 1 >= @buffy.size
      @idx += str_sz
      if @buffy[@idx] != 0
        raise InvalidPacketException, "Type is not nul-terminated"
      end
      @idx += 1
      # no exception, see check above
      ret
    end

    # Based on the _signature_ type, retrieve a packet from the buffer
    # and return it.
    def do_parse(signature)
      packet = nil
      case signature.sigtype
      when Type::BYTE
        packet = get(1).unpack("C")[0]
      when Type::UINT16
        align2
        packet = get(2).unpack(@uint16)[0]
      when Type::UINT32
        align4
        packet = get(4).unpack(@uint32)[0]
      when Type::BOOLEAN
        align4
        v = get(4).unpack(@uint32)[0]
        raise InvalidPacketException if not [0, 1].member?(v)
        packet = (v == 1)
      when Type::ARRAY
        align4
        # checks please
        array_sz = get(4).unpack(@uint32)[0]
        raise InvalidPacketException if array_sz > 67108864
        
        align(signature.child.alignment)
        raise IncompleteBufferException if @idx + array_sz > @buffy.size

        packet = Array.new
        start_idx = @idx
        while @idx - start_idx < array_sz
          packet << do_parse(signature.child)
        end
      when Type::STRUCT
        align8
        packet = Array.new
        signature.members.each do |elem|
          packet << do_parse(elem)
        end
      when Type::VARIANT
        string = get_nul_terminated
        # error checking please
        sig = Type::Parser.new(string).parse[0]
        packet = do_parse(sig)
      when Type::OBJECT_PATH
        packet = getstring
      when Type::STRING
        packet = getstring
      when Type::SIGNATURE
        packet = getsignature
      else
        raise NotImplementedException,
        	"sigtype: #{signature.sigtype} (#{signature.sigtype.chr})"
      end
      packet
    end # def do_parse
  end # class PacketUnmarshaller

  # D-Bus packet marshaller class
  #
  # Class that handles the conversion (unmarshalling) of Ruby objects to
  # (binary) payload data.
  class PacketMarshaller
    # The current or result packet.
    attr_reader :packet

    # Create a new marshaller, setting the current packet to the
    # empty packet.
    def initialize
      @packet = ""
    end

    # Align the buffer with NULL (\0) bytes on a 2 byte length.
    def align2
      @packet = @packet.ljust(@packet.length + 1 & ~1, 0.chr)
    end

    # Align the buffer with NULL (\0) bytes on a 4 byte length.
    def align4
      @packet = @packet.ljust(@packet.length + 3 & ~3, 0.chr)
    end

    # Align the buffer with NULL (\0) bytes on a 8 byte length.
    def align8
      @packet = @packet.ljust(@packet.length + 7 & ~7, 0.chr)
    end

    # Align the buffer with NULL (\0) bytes on a byte length of _a_.
    def align(a)
      # FIXME: same fixme as with PacketUnmarshaller#align
      case a
      when 1
      when 2
        align2
      when 4
        align4
      when 8
        align8
      else
        raise "Unsupported alignment"
      end
    end

    # Append the string type and the string _str_ itself to the packet.
    #
    # FIXME: should be called set_string
    def setstring(str)
      align4
      @packet += [str.length].pack("L") + str + "\0"
    end

    # Append the signature type and the signature _signature_ itself to the
    # packet.
    #
    # FIXME: should be called set_signature
    def setsignature(str)
      @packet += str.length.chr + str + "\0"
    end

    # Append the array type _type_ to the packet and allow for appending
    # the child elements.
    def array(type)
      sizeidx = @packet.size
      @packet += "ABCD"
      align(type.alignment)
      contentidx = @packet.size
      yield
      sz = @packet.size - contentidx
      raise InvalidPacketException if sz > 67108864
      @packet[sizeidx...sizeidx + 4] = [sz].pack("L")
    end

    # Align and allow for appending struct fields.
    def struct
      align8
      yield
    end

    # Append a string of bytes without type.
    def append_string(s)
      @packet += s + "\0"
    end

    # Append a value _val_ to the packet based on its _type_.
    def append(type, val)
      type = type.chr if type.kind_of?(Fixnum)
      type = Type::Parser.new(type).parse[0] if type.kind_of?(String)
      case type.sigtype
      when Type::BYTE
        @packet += val.chr
      when Type::UINT32
        align4
        @packet += [val].pack("L")
      when Type::BOOLEAN
        align4
        if val
          @packet += [1].pack("L")
        else
          @packet += [0].pack("L")
        end
      when Type::OBJECT_PATH
        setstring(val)
      when Type::STRING
        setstring(val)
      when Type::SIGNATURE
        setsignature(val)
      when Type::ARRAY
        raise TypeException if not val.kind_of?(Array)
        array(type.child) do
          val.each do |elem|
            append(type.child, elem)
          end
        end
      when Type::STRUCT
        raise TypeException if not val.kind_of?(Array)
        struct do
          idx = 0
          while val[idx] != nil
            type.members.each do |subtype|
              raise TypeException if data[idx] == nil
              append_sig(subtype, data[idx])
              idx += 1
            end
          end
        end
      else
        raise NotImplementedException
      end
    end # def append
  end # class PacketMarshaller

  # = D-Bus message class
  #
  # Class that holds any type of message that travels over the bus.
  class Message
    # The serial number of the message.
    @@serial = 1
    # Mutex that protects updates on the serial number.
    @@serial_mutex = Mutex.new
    # Type of a message (by specification).
    MESSAGE_SIGNATURE = "yyyyuua(yyv)"

    # FIXME: following message type constants should be under Message::Type IMO
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
    # The path of the object the message must be sent to/is sent from.
    attr_accessor :path
    # The interface of the object that must be used/was used.
    attr_accessor :interface
    # The interface member (method) of the object that must be used/was used.
    attr_accessor :member
    # The name of the error (in case of an error message type).
    attr_accessor :error_name
    # The destination connection of the object that must be used/was used.
    attr_accessor :destination
    # The sender of the message.
    attr_accessor :sender
    # The signature of the message contents.
    attr_accessor :signature
    # The serial number of the message this message is a reply for. FIXME: right?
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
      message_type = mtype

      @flags = 0
      @protocol = 1
      @body_length = 0
      @signature = ""
      @@serial_mutex.synchronize do
        @serial = @@serial
        @@serial += 1
      end
      @params = Array.new

      if mtype == METHOD_RETURN
        @flags = NO_REPLY_EXPECTED
      end
    end

    # Set the message type to _mt_ (_mt_ is given in constant name string form).
    #
    # FIXME: odd method, these already exist in Ruby space as constants, why
    # introduce strings as well... Message::Type::SIGNAL should be fine.
    def message_type=(mt)
      @message_type = mt
      @mt = ["INVALID", "METHOD_CALL", "METHOD_RETURN", "ERROR", "SIGNAL"][mt]
    end

    # Increases the last seen serial number?
    #
    # FIXME: strange place for a class method
    # FIXME: an operation on @@serial that is unprotected?
    def Message.serial_seen(s)
      if s > @@serial
        @@serial = s + 1
      end
    end

    # Mark this message as a reply to a another message _m_, taking
    # the serial number of _m_ as reply serial and the sender of _m_ as
    # destination.
    def reply_to(m)
      @reply_serial = m.serial
      @destination = m.sender
      #@interface = m.interface
      #@member = m.member
      self
    end

    # Add a parameter _val_ of type _type_ to the message.
    def add_param(type, val)
      type = type.chr if type.kind_of?(Fixnum)
      @signature += type.to_s
      @params << [type, val]
    end

    # FIXME: what are these? a message element constant enumeration?

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
            marshaller.append_string("o")
            marshaller.append(Type::OBJECT_PATH, @path)
          end
        end
        if @destination
          marshaller.struct do
            marshaller.append(Type::BYTE, DESTINATION)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_string("s")
            marshaller.append(Type::STRING, @destination)
          end
        end
        if @interface
          marshaller.struct do
            marshaller.append(Type::BYTE, INTERFACE)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_string("s")
            marshaller.append(Type::STRING, @interface)
          end
        end
        if @member
          marshaller.struct do
            marshaller.append(Type::BYTE, MEMBER)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_string("s")
            marshaller.append(Type::STRING, @member)
          end
        end
        if @signature != ""
          marshaller.struct do
            marshaller.append(Type::BYTE, SIGNATURE)
            marshaller.append(Type::BYTE, 1)
            marshaller.append_string("g")
            marshaller.append(Type::SIGNATURE, @signature)
          end
        end
      end
      marshaller.align8
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
      dummy, @message_type, @flags, @protocol, @body_length, @serial,
        headers = pu.unmarshall(MESSAGE_SIGNATURE)
      headers.each do |struct|
        case struct[0]
        when PATH
          @path = struct[2]
        when INTERFACE
          @interface = struct[2]
        when MEMBER
          @member = struct[2]
        when ERROR_NAME
          @error_name = struct[2]
        when REPLY_SERIAL
          @reply_serial = struct[2]
        when DESTINATION
          @destination = struct[2]
        when SENDER
          @sender = struct[2]
        when SIGNATURE
          @signature = struct[2]
        end
      end
      pu.align8
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

  # Exception that is raised when an incomplete buffer is encountered.
  class IncompleteBufferException < Exception
  end

  # D-Bus main connection class
  #
  # Main class that maintains a connection to a bus and can handle incoming
  # and outgoing messages.
  class Connection
    # The unique name (by specification) of the message.
    attr_reader :unique_name
    # The socket that is used to connect with the bus.
    attr_reader :socket

    # Create a new connection to the bus for a given connect _path_
    # (UNIX socket).
    def initialize(path)
      @path = path
      @unique_name = nil
      @buffer = ""
      @method_call_replies = Hash.new
      @method_call_msgs = Hash.new
      @proxy = nil
      @socket = Socket.new(Socket::Constants::PF_UNIX,
                           Socket::Constants::SOCK_STREAM, 0)
      @object_root = Node.new("/")
    end

    # Connect to the bus and initialize the connection by saying 'Hello'.
    def connect
      parse_session_string
      if @type == "unix:abstract"
        if HOST_END == LIL_END
          sockaddr = "\1\0\0#{@unix_abstract}"
        else
          sockaddr = "\0\1\0#{@unix_abstract}"
        end
      elsif @type == "unix"
        sockaddr = Socket.pack_sockaddr_un(@unix)
      end
      @socket.connect(sockaddr)
      init_connection
      send_hello
    end

    # Write _s_ to the socket followed by CR LF.
    def writel(s)
      @socket.write("#{s}\r\n")
    end

    # Send the buffer _buf_ to the bus using Connection#writel.
    def send(buf)
      @socket.write(buf)
    end

    # Read data (a buffer) from the bus until CR LF is encountered.
    # Return the buffer without the CR LF characters.
    def readl
      @socket.readline.chomp
    end

    # FIXME: describe the following names, flags and constants.
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
      <arg name="data" direction="out" type="s"/>
    </method>
  </interface>
  <interface name="org.freedesktop.DBus">
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
    <method name="Hello">
      <arg direction="out" type="s"/>
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
    <method name="GetConnectionSELinuxSecurityContext">
      <arg direction="in" type="s"/>
      <arg direction="out" type="ay"/>
    </method>
    <method name="ReloadConfig">
    </method>
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

    # FIXME: describe this
    def introspect(dest, path)
      m = DBus::Message.new(DBus::Message::METHOD_CALL)
      m.path = path
      m.interface = "org.freedesktop.DBus.Introspectable"
      m.destination = dest
      m.member = "Introspect"
      m.sender = unique_name
      ret = nil
      if not block_given?
        # introspect in synchronous !
        send_sync(m) do |rmsg|
          pof = DBus::ProxyObjectFactory.new(rmsg.params[0], self, dest, path)
          return pof.build
        end
      else
        send(m.marshall)
        on_return(m) do |rmsg|
          inret = rmsg.params[0]
          yield(DBus::ProxyObjectFactory.new(inret, self, dest, path).build)
        end
      end
    end

    # Set up a proxy for ... (FIXME).
    def proxy
      if @proxy == nil
        path = "/org/freedesktop/DBus"
        dest = "org.freedesktop.DBus"
        pof = DBus::ProxyObjectFactory.new(DBUSXMLINTRO, self, dest, path)
        @proxy = pof.build["org.freedesktop.DBus"]
      end
      @proxy
    end

    # Fill (append) the buffer from data that might be available on the
    # socket.
    def update_buffer
      @buffer += @socket.read_nonblock(MSG_BUF_SIZE)
    end

    # Get one message from the bus and remove it from the buffer.
    # Return the message.
    def pop_message
      ret = nil
      begin
        ret, size = Message.new.unmarshall_buffer(@buffer)
        @buffer.slice!(0, size)
      rescue IncompleteBufferException => e
        # fall through, let ret be null
      end
      ret
    end

    # Retrieve all the messages that are currently in the buffer.
    def messages
      ret = Array.new
      while msg = pop_message
        ret << msg
      end
      ret
    end

    MSG_BUF_SIZE = 4096

    # Update the buffer and retrieve all messages using Connection#messages.
    # Return the messages.
    def poll_messages
      ret = nil
      r, d, d = IO.select([@socket], nil, nil, 0)
      if r and r.size > 0
        update_buffer
      end
      messages
    end

    # Wait for a message to arrive. Return it once it is available.
    def wait_for_message
      ret = pop_message
      while ret == nil
        r, d, d = IO.select([@socket])
        if r and r[0] == @socket
          update_buffer
          ret = pop_message
        end
      end
      ret
    end

    # Send a message _m_ on to the bus. This is done synchronously, thus
    # the call will block until a reply message arrives.
    def send_sync(m, &retc) # :yields: reply/return message
      send(m.marshall)
      @method_call_msgs[m.serial] = m
      @method_call_replies[m.serial] = retc

      retm = wait_for_message
      until retm.message_type == DBus::Message::METHOD_RETURN and
          retm.reply_serial == m.serial
        retm = wait_for_message
        process(retm)
      end
      process(retm)
    end

    # FIXME: this does nothing yet, really?
    def on_return(m, &retc)
      @method_call_msgs[m.serial] = m
      @method_call_replies[m.serial] = retc
    end

    # Process a message _m) based on its type.
    # method call:: FIXME...
    # method call return value:: FIXME...
    # signal:: FIXME...
    # error:: FIXME...
    def process(m)
      Message.serial_seen(m.serial) if m.serial
      case m.message_type
      when DBus::Message::METHOD_RETURN
        raise InvalidPacketException if m.reply_serial == nil
        mcs = @method_call_replies[m.reply_serial]
        if not mcs
          puts "no return code for #{mcs.inspect} (#{m.inspect})"
        else
          mcs.call(m)
          @method_call_replies.delete(m.reply_serial)
          @method_call_msgs.delete(m.reply_serial)
        end
      when DBus::Message::METHOD_CALL
        # handle introspectable as an exception:
        p m
        if m.interface == "org.freedesktop.DBus.Introspectable" and
          m.member == "Introspect"
          reply = Message.new(Message::METHOD_RETURN).reply_to(m)
          reply.sender = @unique_name
          p @unique_name
          node = get_node(m.path)
          raise NotImplementedException if not node
          p get_node(m.path).to_xml
          reply.sender = @unique_name
          reply.add_param(Type::STRING, get_node(m.path).to_xml)
          s = reply.marshall
          p reply
          p Message.new.unmarshall(s)
          send(reply.marshall)
        end
      else
        p m
      end
    end

    # FIXME: what does this do? looks very private too.
    def get_node(path, create = false)
      n = @object_root
      path.split("/") do |elem|
        if not n[elem]
          if not create
            return false
          else
            n[elem] = Node.new(elem)
          end
        end
        n = n[elem]
      end
      n
    end

    # Exports an object with an D-Bus interface on the bus.
    def export_object(object)
      n = get_node(object.path, true)
      n.object = object
    end

    ###########################################################################
    private

    # Send a hello messages to the bus to let it know we are here.
    def send_hello
      m = Message.new
      m.message_type = DBus::Message::METHOD_CALL
      m.path = "/org/freedesktop/DBus"
      m.destination = "org.freedesktop.DBus"
      m.interface = "org.freedesktop.DBus"
      m.member = "Hello"
      send_sync(m) do |rmsg|
        @unique_name = rmsg.destination
        puts "Got hello reply. Our unique_name is #{@unique_name}"
      end
    end

    # Parse the session string (socket address).
    def parse_session_string
      @path.split(",").each do |eqstr|
        idx, val = eqstr.split("=")
        case idx
        when "unix"
          @type = idx
          @unix = val
        when "unix:abstract"
          @type = idx
          @unix_abstract = val
        when "guid"
          @guid = val
        end
      end
    end

    # Initialize the connection to the bus.
    def init_connection
      @socket.write("\0")
      # TODO: code some real stuff here
      writel("AUTH EXTERNAL 31303030")
      s = readl
      # parse OK ?
      writel("BEGIN")
    end

  end # class Connection
end # module DBus
