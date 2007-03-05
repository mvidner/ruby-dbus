#!/usr/bin/ruby

require 'dbus/type'

require 'socket'
require 'thread'

module DBus

  BIG_END = ?B
  LIL_END = ?l

  if [0x01020304].pack("L").unpack("V")[0] == 0x01020304
    HOST_END = LIL_END
  else
    HOST_END = BIG_END
  end

  class InvalidPacketException < Exception
  end

  class NotImplementedException < Exception
  end

  class PacketUnmarshaller
    def initialize(buffer, endianness)
      @buffy, @endianness = buffer.dup, endianness
      if @endianness == BIG_END
        @uint32 = "N"
      elsif @endianness == LIL_END
        @uint32 = "V"
      else
        raise Exception, "Incorrect endianneess"
      end
      @idx = 0
    end

    def unmarshall(signature, len = nil)
      if len != nil
        if not @buffy.size >= @idx + len
          raise Exception
        end
      end
      sigtree = Type::Parser.new(signature).parse
      ret = Array.new
      sigtree.each do |elem|
        ret << do_parse(elem)
      end
      ret
    end

    def align8
      @idx = @idx + 7 & ~7
    end

    private

    def get(nbytes)
      ret = @buffy.slice(@idx, nbytes)
      @idx += nbytes
      ret
    end

    def get_nul_terminated
      @buffy[@idx..-1] =~ /^([^\0]*)/
      str = $1
      @idx += str.size + 1
      str
    end

    def getstring
      str_sz = get(4).unpack(@uint32)[0]
      ret = @buffy.slice(@idx, str_sz)
      @idx += str_sz
      if @buffy[@idx] != 0
        raise InvalidPacketException, "String is not nul-terminated"
      end
      @idx += 1
      ret
    end

    def getsignature
      str_sz = get(1).unpack('C')[0]
      ret = @buffy.slice(@idx, str_sz)
      @idx += str_sz
      if @buffy[@idx] != 0
        raise InvalidPacketException, "Type is not nul-terminated"
      end
      @idx += 1
      ret
    end

    def do_parse(signature)
      packet = nil
      case signature.sigtype
      when Type::BYTE
        packet = get(1).unpack("C")[0]
      when Type::UINT32
        packet = get(4).unpack(@uint32)[0]
      when Type::ARRAY
        # checks please
        array_sz = get(4).unpack(@uint32)[0]
        raise InvalidPacketException if array_sz > 67108864
        packet = Array.new
        align8
        arraydata = @buffy[@idx, array_sz]
        if arraydata.size != array_sz
          raise Exception, "blah"
        end
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
    end
  end

  class PacketMarshaller
    attr_reader :packet
    def initialize
      @packet = ""
    end

    def align8
      @packet = @packet.ljust(@packet.length + 7 & ~7, 0.chr)
    end

    def dump
      p @packet
    end

    def setstring(str)
      ret = ""
      ret += [str.length].pack("L")
      ret += str + "\0"
      ret
    end

    def setsignature(str)
      ret = ""
      ret += str.length.chr
      ret += str + "\0"
      ret
    end

    def array
      sizeidx = @packet.size
      @packet += "ABCD"
      align8
      yield
      sz = @packet.size - sizeidx - 4
      raise InvalidPacketException if sz > 67108864
      @packet[sizeidx...sizeidx + 4] = [sz].pack("L")
    end

    def struct
      align8
      yield
    end

    def append_string(s)
      @packet += s + "\0"
    end

    def append(type, val)
      case type
      when Type::BYTE
        @packet += val.chr
      when Type::UINT32
        @packet += [val].pack("L")
      when Type::OBJECT_PATH
        @packet += setstring(val)
      when Type::STRING
        @packet += setstring(val)
      when Type::SIGNATURE
        @packet += setsignature(val)
      else
        raise Exception, "not implemented"
      end
    end
  end

  class Message
    @@serial = 0
    @@serial_mutex = Mutex.new
    MESSAGE_SIGNATURE = "yyyyuua(yyv)"

    INVALID = 0
    METHOD_CALL = 1
    METHOD_RETURN = 2
    ERROR = 3
    SIGNAL = 4

    NO_REPLY_EXPECTED = 0x1
    NO_AUTO_START = 0x2

    attr_accessor :message_type, :serial
    attr_accessor :path, :interface, :member, :error_name, :destination,
      :sender, :signature
    attr_reader :protocol

    def initialize
      @message_type = 0
      @flags = 0
      @protocol = 1
      @body_length = 0
      @signature = ""
      @@serial_mutex.synchronize do
        @serial = @@serial
        @@serial += 1
      end
      @params = Array.new
    end

    def add_param(type, val)
      @signature += type.chr
      @params << [type, val]
    end

    PATH = 1
    INTERFACE = 2
    MEMBER = 3
    ERROR_NAME = 4
    REPLY_SERIAL = 5
    DESTINATION = 6
    SENDER = 7
    SIGNATURE = 8

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
      marshaller.array do
        if @signature != ""
          marshaller.struct do
            marshaller.append(Type::BYTE, Type::SIGNATURE)
            marshaller.append_string("g")
            marshaller.append(Type::SIGNATURE, @signature)
          end
        end
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
      end
      marshaller.align8
      @params.each do |param|
        marshaller.append(param[0], param[1])
      end
      marshaller.packet + params.packet
    end

    def unmarshall(buf)
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
        pu.unmarshall(@signature, @body_length)
      end
      self
    end
  end

  class Connection
    def initialize(path)
      @path = path
    end

    # You need a patched libruby for this to connect
    def connect
      parse_session_string
      @socket = Socket.new(Socket::Constants::PF_UNIX,
                           Socket::Constants::SOCK_STREAM, 0)
      sockaddr = Socket.pack_sockaddr_un("\0" + @unix_abstract)
      @socket.connect(sockaddr)
      init_connection
      send_hello
    end

    def writel(s)
      @socket.write("#{s}\r\n")
    end

    def send(buf)
      @socket.write(buf)
    end

    def read
      a = 0
      begin
        @socket.read_nonblock(2048)
      rescue Errno::EAGAIN
        if a == 3
          return
        else
          a += 1
        end
        retry
      end
    end

    def readl
      @socket.readline.chomp
    end

    NAME_FLAG_ALLOW_REPLACEMENT = 0x1
    NAME_FLAG_REPLACE_EXISTING = 0x2
    NAME_FLAG_DO_NOT_QUEUE = 0x4

    REQUEST_NAME_REPLY_PRIMARY_OWNER = 0x1
    REQUEST_NAME_REPLY_IN_QUEUE = 0x2
    REQUEST_NAME_REPLY_EXISTS = 0x3
    REQUEST_NAME_REPLY_ALREADY_OWNER = 0x4

    def request_name(name, flags)
      m = Message.new
      m.message_type = DBus::Message::METHOD_CALL
      m.serial = 1
      m.path = "/org/freedesktop/DBus"
      m.destination = "org.freedesktop.DBus"
      m.interface = "org.freedesktop.DBus"
      m.member = "RequestName"
      m.add_param(Type::STRING, name)
      m.add_param(Type::UINT32, flags)
      s = m.marshall
      p s
      send(s)
      r, d, d = IO.select([@socket])
      if r and r[0] == @socket
        m = read
      end
      ret = Message.new.unmarshall(m)
      if ret.serial == m.serial and
        ret.message_type == Message::METHOD_RETURN and
        ret.sender == "org.freedesktop.DBus" and ret.protocol == 1
        # this is our unique name
        @unique_name = ret.destination
        puts "Got hello reply. Our unique_name is #{@unique_name}"
      end
    end

    private
    def send_hello
      m = Message.new
      m.message_type = DBus::Message::METHOD_CALL
      m.serial = 1
      m.path = "/org/freedesktop/DBus"
      m.destination = "org.freedesktop.DBus"
      m.interface = "org.freedesktop.DBus"
      m.member = "Hello"
      send(m.marshall)
      r, d, d = IO.select([@socket])
      if r and r[0] == @socket
        buf = read
      end
      ret = Message.new.unmarshall(buf)
      if ret.serial == m.serial and
        ret.message_type == Message::METHOD_RETURN and
        ret.sender == "org.freedesktop.DBus" and ret.protocol == 1
        # this is our unique name
        @unique_name = ret.destination
        puts "Got hello reply. Our unique_name is #{@unique_name}"
      end
    end

    def parse_session_string
      @path.split(",").each do |eqstr|
        idx, val = eqstr.split("=")
        case idx
        when "unix:abstract"
          @unix_abstract = val
        when "guid"
          @guid = val
        end
      end
    end

    def init_connection
      @socket.write("\0")
      # TODO: code some real stuff here
      writel("AUTH EXTERNAL 31303030")
      s = readl
      p s
      # parse ?
      writel("BEGIN")
    end
  end
end # module DBus

