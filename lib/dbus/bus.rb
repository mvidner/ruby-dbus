# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'socket'
require 'thread'
require 'singleton'
require 'fcntl'

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # This represents a remote service. It should not be instantiated directly
  # Use Bus::service()
  class Service
    # The service name.
    attr_reader :name
    # The bus the service is running on.
    attr_reader :bus
    # The service root (FIXME).
    attr_reader :root

    # Create a new service with a given _name_ on a given _bus_.
    def initialize(name, bus)
      @name, @bus = name, bus
      @root = Node.new("/")
    end

    # Determine whether the service name already exists.
    def exists?
      bus.proxy.ListNames[0].member?(@name)
    end

    # Perform an introspection on all the objects on the service
    # (starting recursively from the root).
    def introspect
      if block_given?
        raise NotImplementedError
      else
        rec_introspect(@root, "/")
      end
      self
    end

    # Retrieves an object (ProxyObject) at the given _path_.
    def object(path)
      node = get_node(path, true)
      if node.object.nil?
        node.object = ProxyObject.new(@bus, @name, path)
      end
      node.object
    end

    # Export an object _obj_ (an DBus::Object subclass instance).
    def export(obj)
      obj.service = self
      get_node(obj.path, true).object = obj
    end

    # Undo exporting an object _obj_.
    # Raises ArgumentError if it is not a DBus::Object.
    # Returns the object, or false if _obj_ was not exported.
    def unexport(obj)
      raise ArgumentError.new("DBus::Service#unexport() expects a DBus::Object argument") unless obj.kind_of?(DBus::Object)
      return false unless obj.path
      pathSep = obj.path.rindex("/") #last path seperator
      parent_path = obj.path[1..pathSep-1]
      node_name = obj.path[pathSep+1..-1]

      parent_node = get_node(parent_path, false)
      return false unless parent_node
      obj.service = nil
      parent_node.delete(node_name)
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
        puts "Warning, unknown object #{path}" if $DEBUG
      end
      n
    end

    #########
    private
    #########

    # Perform a recursive retrospection on the given current _node_
    # on the given _path_.
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

  # = Object path node class
  #
  # Class representing a node on an object path.
  class Node < Hash
    # The D-Bus object contained by the node.
    attr_accessor :object
    # The name of the node.
    attr_reader :name

    # Create a new node with a given _name_.
    def initialize(name)
      @name = name
      @object = nil
    end

    # Return an XML string representation of the node.
    # It is shallow, not recursing into subnodes
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

    # Return inspect information of the node.
    def inspect
      # Need something here
      "<DBus::Node #{sub_inspect}>"
    end

    # Return instance inspect information, used by Node#inspect.
    def sub_inspect
      s = ""
      if not @object.nil?
        s += "%x " % @object.object_id
      end
      s + "{" + keys.collect { |k| "#{k} => #{self[k].sub_inspect}" }.join(",") + "}"
    end
  end # class Inspect

  # FIXME: rename Connection to Bus?

  # D-Bus main connection class
  #
  # Main class that maintains a connection to a bus and can handle incoming
  # and outgoing messages.
  class Connection
    # The unique name (by specification) of the message.
    attr_reader :unique_name
    # The socket that is used to connect with the bus.
    attr_reader :socket

    # Create a new connection to the bus for a given connect _path_. _path_
    # format is described in the D-Bus specification:
    # http://dbus.freedesktop.org/doc/dbus-specification.html#addresses
    # and is something like:
    # "transport1:key1=value1,key2=value2;transport2:key1=value1,key2=value2"
    # e.g. "unix:path=/tmp/dbus-test" or "tcp:host=localhost,port=2687"
    def initialize(path)
      @path = path
      @unique_name = nil
      @buffer = ""
      @method_call_replies = Hash.new
      @method_call_msgs = Hash.new
      @signal_matchrules = Hash.new
      @proxy = nil
      @object_root = Node.new("/")
      @is_tcp = false
    end

    # Connect to the bus and initialize the connection.
    def connect
      addresses = @path.split ";"
      # connect to first one that succeeds
      worked = addresses.find do |a|
        transport, keyvaluestring = a.split ":"
        kv_list = keyvaluestring.split ","
        kv_hash = Hash.new
        kv_list.each do |kv|
          key, escaped_value = kv.split "="
          value = escaped_value.gsub(/%(..)/) {|m| [$1].pack "H2" }
          kv_hash[key] = value
        end
        case transport
          when "unix"
          connect_to_unix kv_hash
          when "tcp"
          connect_to_tcp kv_hash
          else
          # ignore, report?
        end
      end
      worked
      # returns the address that worked or nil.
      # how to report failure?
    end

    # Connect to a bus over tcp and initialize the connection.
    def connect_to_tcp(params)
      #check if the path is sufficient
      if params.key?("host") and params.key?("port")
        begin
          #initialize the tcp socket
          @socket = TCPSocket.new(params["host"],params["port"].to_i)
          @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
          init_connection
          @is_tcp = true
        rescue
          puts "Error: Could not establish connection to: #{@path}, will now exit."
          exit(0) #a little harsh
        end
      else
        #Danger, Will Robinson: the specified "path" is not usable
        puts "Error: supplied path: #{@path}, unusable! sorry."
      end
    end

    # Connect to an abstract unix bus and initialize the connection.
    def connect_to_unix(params)
      @socket = Socket.new(Socket::Constants::PF_UNIX,Socket::Constants::SOCK_STREAM, 0)
      @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      if ! params['abstract'].nil?
        if HOST_END == LIL_END
          sockaddr = "\1\0\0#{params['abstract']}"
        else
          sockaddr = "\0\1\0#{params['abstract']}"
        end
      elsif ! params['path'].nil?
        sockaddr = Socket.pack_sockaddr_un(params['path'])
      end
      @socket.connect(sockaddr)
      init_connection
    end

    # Send the buffer _buf_ to the bus using Connection#writel.
    def send(buf)
      @socket.write(buf) unless @socket.nil?
    end

    # Tell a bus to register itself on the glib main loop
    def glibize
      require 'glib2'
      # Circumvent a ruby-glib bug
      @channels ||= Array.new

      gio = GLib::IOChannel.new(@socket.fileno)
      @channels << gio
      gio.add_watch(GLib::IOChannel::IN) do |c, ch|
        update_buffer
        messages.each do |msg|
          process(msg)
        end
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
# This apostroph is for syntax highlighting editors confused by above xml: "

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
          if rmsg.is_a?(Error)
            raise rmsg
          else
            ret = rmsg.params
          end
        end
      else
        on_return(message) do |rmsg|
          if rmsg.is_a?(Error)
            reply_handler.call(rmsg)
          else
            reply_handler.call(rmsg, * rmsg.params)
          end
        end
        send(message.marshall)
      end
      ret
    end

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
          # TODO test async introspection, is it used at all?
          args.shift            # forget the message, pass only the text
          reply_handler.call(*args)
          nil
        end
      end
    end

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
        introspect_data(dest, path) do |async_data|
          yield(DBus::ProxyObjectFactory.new(async_data, self, dest, path).build)
        end
      end
    end

    # Exception raised when a service name is requested that is not available.
    class NameRequestError < Exception
    end

    # Attempt to request a service _name_.
    #
    # FIXME, NameRequestError cannot really be rescued as it will be raised
    # when dispatching a later call. Rework the API to better match the spec.
    def request_service(name)
      # Use RequestName, but asynchronously!
      # A synchronous call would not work with service activation, where
      # method calls to be serviced arrive before the reply for RequestName
      # (Ticket#29).
      proxy.RequestName(name, NAME_FLAG_REPLACE_EXISTING) do |rmsg, r|
        if rmsg.is_a?(Error)  # check and report errors first
	  raise rmsg
	elsif r != REQUEST_NAME_REPLY_PRIMARY_OWNER
          raise NameRequestError
	end
      end
      @service = Service.new(name, self)
      @service
    end

    # Set up a ProxyObject for the bus itself, since the bus is introspectable.
    # Returns the object.
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
    rescue EOFError
      raise                     # the caller expects it
    rescue Exception => e
      puts "Oops:", e
      raise if @is_tcp          # why?
      puts "WARNING: read_nonblock failed, falling back to .recv"
      @buffer += @socket.recv(MSG_BUF_SIZE)  
    end

    # Get one message from the bus and remove it from the buffer.
    # Return the message.
    def pop_message
      return nil if @buffer.empty?
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

    # The buffer size for messages.
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
      if @socket.nil?
        puts "ERROR: Can't wait for messages, @socket is nil."
        return
      end
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
      return if m.nil? #check if somethings wrong
      send(m.marshall)
      @method_call_msgs[m.serial] = m
      @method_call_replies[m.serial] = retc

      retm = wait_for_message
      
      return if retm.nil? #check if somethings wrong
      
      process(retm)
      until [DBus::Message::ERROR,
          DBus::Message::METHOD_RETURN].include?(retm.message_type) and
          retm.reply_serial == m.serial
        retm = wait_for_message
        process(retm)
      end
    end

    # Specify a code block that has to be executed when a reply for
    # message _m_ is received.
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
      mrs = mr.to_s
      puts "#{@signal_matchrules.size} rules, adding #{mrs.inspect}" if $DEBUG
      # don't ask for the same match if we override it
      unless @signal_matchrules.key?(mrs)
        puts "Asked for a new match" if $DEBUG
        proxy.AddMatch(mrs)
      end
      @signal_matchrules[mrs] = slot
    end

    def remove_match(mr)
      mrs = mr.to_s
      unless @signal_matchrules.delete(mrs).nil?
        # don't remove nonexisting matches.
        # FIXME if we do try, the Error.MatchRuleNotFound is *not* raised
        # and instead is reported as "no return code for nil"
        proxy.RemoveMatch(mrs)
      end
    end

    # Process a message _m_ based on its type.
    def process(m)
      return if m.nil? #check if somethings wrong
      case m.message_type
      when Message::ERROR, Message::METHOD_RETURN
        raise InvalidPacketException if m.reply_serial == nil
        mcs = @method_call_replies[m.reply_serial]
        if not mcs
          puts "DEBUG: no return code for mcs: #{mcs.inspect} m: #{m.inspect}" if $DEBUG
        else
          if m.message_type == Message::ERROR
            mcs.call(Error.new(m))
          else
            mcs.call(m)
          end
          @method_call_replies.delete(m.reply_serial)
          @method_call_msgs.delete(m.reply_serial)
        end
      when DBus::Message::METHOD_CALL
        if m.path == "/org/freedesktop/DBus"
          puts "DEBUG: Got method call on /org/freedesktop/DBus" if $DEBUG
        end
        node = @service.get_node(m.path)
        if not node
          reply = Message.error(m, "org.freedesktop.DBus.Error.UnknownObject",
                                "Object #{m.path} doesn't exist")
          send(reply.marshall)
        # handle introspectable as an exception:
        elsif m.interface == "org.freedesktop.DBus.Introspectable" and
            m.member == "Introspect"
          reply = Message.new(Message::METHOD_RETURN).reply_to(m)
          reply.sender = @unique_name
          reply.add_param(Type::STRING, node.to_xml)
          send(reply.marshall)
        else
          obj = node.object
          return if obj.nil?    # FIXME, sends no reply
          obj.dispatch(m) if obj
        end
      when DBus::Message::SIGNAL
        # the signal can match multiple different rules
        @signal_matchrules.each do |mrs, slot|
          if DBus::MatchRule.new.from_s(mrs).match(m)
            slot.call(m)
          end
        end
      else
        puts "DEBUG: Unknown message type: #{m.message_type}" if $DEBUG
      end
    end

    # Retrieves the Service with the given _name_.
    def service(name)
      # The service might not exist at this time so we cannot really check
      # anything
      Service.new(name, self)
    end
    alias :[] :service

    # Emit a signal event for the given _service_, object _obj_, interface
    # _intf_ and signal _sig_ with arguments _args_.
    def emit(service, obj, intf, sig, *args)
      m = Message.new(DBus::Message::SIGNAL)
      m.path = obj.path
      m.interface = intf.name
      m.member = sig.name
      m.sender = service.name
      i = 0
      sig.params.each do |par|
        m.add_param(par.type, args[i])
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
        puts "Got hello reply. Our unique_name is #{@unique_name}" if $DEBUG
      end
      @service = Service.new(@unique_name, self)
    end

    # Initialize the connection to the bus.
    def init_connection
      @client = Client.new(@socket)
      @client.authenticate
    end
  end # class Connection


  # = D-Bus session bus class
  #
  # The session bus is a session specific bus (mostly for desktop use).
  #
  # Use SessionBus, the non-singleton ASessionBus is
  # for the test suite.
  class ASessionBus < Connection
    # Get the the default session bus.
    def initialize
      super(ENV["DBUS_SESSION_BUS_ADDRESS"] || address_from_file)
      connect
      send_hello
    end

    def address_from_file
      f = File.new("/var/lib/dbus/machine-id")
      machine_id = f.readline.chomp
      f.close
      display = ENV["DISPLAY"].gsub(/.*:([0-9]*).*/, '\1')
      File.open(ENV["HOME"] + "/.dbus/session-bus/#{machine_id}-#{display}").each do |line|
        if line =~ /^DBUS_SESSION_BUS_ADDRESS=(.*)/
          return $1
        end
      end
    end
  end

  # See ASessionBus
  class SessionBus < ASessionBus
    include Singleton
  end


  # = D-Bus system bus class
  #
  # The system bus is a system-wide bus mostly used for global or
  # system usages.
  #
  # Use SystemBus, the non-singleton ASystemBus is
  # for the test suite.
  class ASystemBus < Connection
    # Get the default system bus.
    def initialize
      super(SystemSocketName)
      connect
      send_hello
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
  # http://github.com/pangdudu/ruby-dbus/blob/master/README.rdoc
  class RemoteBus < Connection

    # Get the remote bus.
    def initialize socket_name
      super(socket_name)
      connect
      send_hello
    end
  end

  # See ASystemBus
  class SystemBus < ASystemBus
    include Singleton
  end

  # Shortcut for the SystemBus instance
  def DBus.system_bus
    SystemBus.instance
  end

  # Shortcut for the SessionBus instance
  def DBus.session_bus
    SessionBus.instance
  end

  # = Main event loop class.
  #
  # Class that takes care of handling message and signal events
  # asynchronously.  *Note:* This is a native implement and therefore does
  # not integrate with a graphical widget set main loop.
  class Main
    # Create a new main event loop.
    def initialize
      @buses = Hash.new
      @quitting = false
    end

    # Add a _bus_ to the list of buses to watch for events.
    def <<(bus)
      @buses[bus.socket] = bus
    end

    # Quit a running main loop, to be used eg. from a signal handler
    def quit
      @quitting = true
    end

    # Run the main loop. This is a blocking call!
    def run
      # before blocking, empty the buffers
      # https://bugzilla.novell.com/show_bug.cgi?id=537401
      @buses.each_value do |b|
        while m = b.pop_message
          b.process(m)
        end
      end
      while not @quitting and not @buses.empty?
        ready, dum, dum = IO.select(@buses.keys)
        ready.each do |socket|
          b = @buses[socket]
          begin
            b.update_buffer
          rescue EOFError, SystemCallError
            @buses.delete socket # this bus died
            next
          end
          while m = b.pop_message
            b.process(m)
          end
        end
      end
    end
  end # class Main
end # module DBus
