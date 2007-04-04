# dbus.rb - Module containing the low-level D-Bus implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'socket'
require 'thread'
require 'singleton'

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # This represents a remote service. It should not be instancied directly
  # Use Bus::service()
  class Service
    attr_reader :name, :bus, :root
    def initialize(name, bus)
      @name, @bus = name, bus
      @root = Node.new("/")
    end

    def exists?
      bus.proxy.ListName.member?(@name)
    end

    def introspect
      if block_given?
        raise NotImplementedError
      else
        rec_introspect(@root, "/")
      end
      self
    end

    def object(path)
      node = get_node(path, true)
      if node.object.nil?
        node.object = ProxyObject.new(@bus, @name, path)
      end
      node.object
    end

    def export(obj)
      obj.service = self
      get_node(obj.path, true).object = obj
    end

    # Get the object node corresponding to the given _path_. if _create_ is
    # true, the the nodes in the path are created if they do not already exist.
    def get_node(path, create = false)
      n = @root
      path.sub(/^\//, "").split("/").each do |elem|
        if not n[elem]
          if not create
            return nil
          else
            n[elem] = Node.new(elem)
          end
        end
        n = n[elem]
      end
      if n.nil?
        puts "Warning, unknown object #{path}"
      end
      n
    end

    private
    def rec_introspect(node, path)
      xml = bus.introspect_data(@name, path)
      intfs, subnodes = IntrospectXMLParser.new(xml).parse
      subnodes.each do |nodename|
        subnode = node[nodename] = Node.new(nodename)
        if path == "/"
          subpath = "/" + nodename
        else
          subpath = path + "/" + nodename
        end
        rec_introspect(subnode, subpath)
      end
      if intfs.size > 0
        node.object = ProxyObjectFactory.new(xml, @bus, @name, path).build
      end
    end
  end

  # node for the object tree
  class Node < Hash
    attr_accessor :object
    attr_reader :name
    def initialize(name)
      @name = name
      @object = nil
    end

    def to_xml
      xml = '<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN"
"http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node>
'
      self.each_pair do |k, v|
        xml += "<node name=\"#{k}\" />"
      end
      if @object
        @object.intfs.each_pair do |k, v|
          xml += %{<interface name="#{v.name}">\n}
          v.methods.each_value { |m| xml += m.to_xml }
          v.signals.each_value { |m| xml += m.to_xml }
          xml +="</interface>\n"
        end
      end
      xml += '</node>'
      xml
    end

    def inspect
      "Node #{super.inspect} #{@object.inspect}"
    end
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
      @signal_matchrules = Array.new
      @proxy = nil
      # FIXME: can be TCP or any stream
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

    # Send the buffer _buf_ to the bus using Connection#writel.
    def send(buf)
      @socket.write(buf)
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

    def introspect_data(dest, path)
      m = DBus::Message.new(DBus::Message::METHOD_CALL)
      m.path = path
      m.interface = "org.freedesktop.DBus.Introspectable"
      m.destination = dest
      m.member = "Introspect"
      m.sender = unique_name
      if not block_given?
        # introspect in synchronous !
        send_sync(m) do |rmsg|
          return rmsg.params[0]
        end
      else
        send(m.marshall)
        on_return(m) do |rmsg|
          yield rmsg.params[0]
        end
      end
      nil
    end

    # FIXME: describe this
    # Issues a call to the org.freedesktop.DBus.Introspectable.Introspect method
    # _dest_ is the service and _path_ the object path you want to introspect
    # If a code block is given, the introspect call in asynchronous. If not
    # data is returned
    #
    # FIXME: link to ProxyObject data definition
    # The returned object is a ProxyObject that has methods you can call to
    # issue somme METHOD_CALL messages, and to setup to receive METHOD_RETURN
    def introspect(dest, path)
      if not block_given?
        # introspect in synchronous !
        data = introspect_data(dest, path)
        pof = DBus::ProxyObjectFactory.new(data, self, dest, path)
        return pof.build
      else
        introspect_data(dest, path) do |data|
          yield(DBus::ProxyObjectFactory.new(data, self, dest, path).build)
        end
      end
    end

    def request_service(name)
      r = proxy.RequestName("org.ruby.service", NAME_FLAG_REPLACE_EXISTING)
      raise NameRequestError if r[0] != REQUEST_NAME_REPLY_PRIMARY_OWNER
      @service = Service.new(name, self)
      @service
    end

    # Set up a proxy for ... (FIXME).
    # Set up a ProxyObject for the bus itself. Since the bus is introspectable.
    #
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
      process(retm)
      until [DBus::Message::ERROR,
          DBus::Message::METHOD_RETURN].include?(retm.message_type) and
          retm.reply_serial == m.serial
        retm = wait_for_message
        process(retm)
      end
    end

    # FIXME: this does nothing yet, really?
    # Actually this is very important, see the retc code block that is stored.
    #
    # When you send a message asynchronously you pass to on_return a code block
    # that will be called on reception of the reply for this message.
    # This just sets up the call back and returns. Code block is called
    # asynchronously.
    #
    # This is how you use this:
    # m = Message.new(Message::METHOD_CALL)
    # m.destination = ...
    # m...
    # m.send
    # bus.on_return(m) do |returned_message|
    # end
    def on_return(m, &retc)
      # Have a better exception here
      if m.message_type != Message::METHOD_CALL
        raise "on_return should only get method_calls"
      end
      @method_call_msgs[m.serial] = m
      @method_call_replies[m.serial] = retc
    end

    # Asks bus to send us messages matching mr, and execute slot when
    # received
    def add_match(mr, &slot)
      # check this is a signal.
      @signal_matchrules << [mr, slot]
      self.proxy.AddMatch(mr.to_s)
    end

    # Process a message _m) based on its type.
    # method call:: FIXME...
    # method call return value:: FIXME...
    # signal:: FIXME...
    # error:: FIXME...
    def process(m)
      case m.message_type
      when DBus::Message::ERROR, DBus::Message::METHOD_RETURN
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
        if m.path == "/org/freedesktop/DBus"
          puts "Got method call on /org/freedesktop/DBus"
        end
        # handle introspectable as an exception:
        if m.interface == "org.freedesktop.DBus.Introspectable" and
            m.member == "Introspect"
          reply = Message.new(Message::METHOD_RETURN).reply_to(m)
          reply.sender = @unique_name
          node = @service.get_node(m.path)
          raise NotImplementedError if not node
          reply.sender = @unique_name
          reply.add_param(Type::STRING, @service.get_node(m.path).to_xml)
          send(reply.marshall)
        else
          node = @service.get_node(m.path)
          return if node.nil?
          obj = node.object
          return if obj.nil?
          obj.dispatch(m) if obj
        end
      when DBus::Message::SIGNAL
        @signal_matchrules.each do |elem|
          mr, slot = elem
          if mr.match(m)
            slot.call(m)
            return
          end
        end
      else
        p m
      end
    end

    def service(str)
      # The service might not exist at this time so we cannot really check
      # anything
      Service.new(str, self)
    end
    alias :[] :service

    def emit(service, obj, intf, sig, *args)
      m = Message.new(DBus::Message::SIGNAL)
      m.path = obj.path
      m.interface = intf.name
      m.member = sig.name
      m.sender = service.name
      i = 0
      sig.params.each do |par|
        m.add_param(par[1], args[i])
        i += 1
      end
      send(m.marshall)
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
      @client = Client.new(@socket)
      @client.authenticate
      # TODO: code some real stuff here
      #writel("AUTH EXTERNAL 31303030")
      #s = readl
      # parse OK ?
      #writel("BEGIN")
    end
  end # class Connection

  class SessionBus < Connection
    include Singleton

    def initialize
      super(ENV["DBUS_SESSION_BUS_ADDRESS"])
      connect
    end
  end

  class SystemBus < Connection
    include Singleton

    def initialize
      super(SystemSocketName)
      connect
    end
  end

  def DBus.system_bus
    SystemBus.instance
  end

  def DBus.session_bus
    SessionBus.instance
  end
end # module DBus
