# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you caan redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "socket"
require "thread"
require "singleton"

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
      @name = name
      @bus = bus
      @root = Node.new("/")
    end

    # Determine whether the service name already exists.
    def exists?
      bus.proxy.ListNames[0].member?(@name)
    end

    # Perform an introspection on all the objects on the service
    # (starting recursively from the root).
    def introspect
      raise NotImplementedError if block_given?

      rec_introspect(@root, "/")
      self
    end

    # Retrieves an object at the given _path_.
    # @return [ProxyObject]
    def [](path)
      object(path, api: ApiOptions::A1)
    end

    # Retrieves an object at the given _path_
    # whose methods always return an array.
    # @return [ProxyObject]
    def object(path, api: ApiOptions::A0)
      node = get_node(path, _create = true)
      if node.object.nil? || node.object.api != api
        node.object = ProxyObject.new(
          @bus, @name, path,
          api: api
        )
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
      raise ArgumentError, "DBus::Service#unexport() expects a DBus::Object argument" unless obj.is_a?(DBus::Object)
      return false unless obj.path
      last_path_separator_idx = obj.path.rindex("/")
      parent_path = obj.path[1..last_path_separator_idx - 1]
      node_name = obj.path[last_path_separator_idx + 1..-1]

      parent_node = get_node(parent_path, false)
      return false unless parent_node
      obj.service = nil
      parent_node.delete(node_name).object
    end

    # Get the object node corresponding to the given _path_. if _create_ is
    # true, the the nodes in the path are created if they do not already exist.
    def get_node(path, create = false)
      n = @root
      path.sub(%r{^/}, "").split("/").each do |elem|
        if !(n[elem])
          return nil if !create
          n[elem] = Node.new(elem)
        end
        n = n[elem]
      end
      if n.nil?
        DBus.logger.debug "Warning, unknown object #{path}"
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
        subpath = if path == "/"
                    "/" + nodename
                  else
                    path + "/" + nodename
                  end
        rec_introspect(subnode, subpath)
      end
      return if intfs.empty?
      node.object = ProxyObjectFactory.new(xml, @bus, @name, path).build
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
      each_pair do |k, _v|
        xml += "<node name=\"#{k}\" />"
      end
      if @object
        @object.intfs.each_pair do |_k, v|
          xml += %(<interface name="#{v.name}">\n)
          v.methods.each_value { |m| xml += m.to_xml }
          v.signals.each_value { |m| xml += m.to_xml }
          xml += "</interface>\n"
        end
      end
      xml += "</node>"
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
      if !@object.nil?
        s += format("%x ", @object.object_id)
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
      @method_call_replies = {}
      @method_call_msgs = {}
      @signal_matchrules = {}
      @proxy = nil
      @object_root = Node.new("/")
    end

    # Dispatch all messages that are available in the queue,
    # but do not block on the queue.
    # Called by a main loop when something is available in the queue
    def dispatch_message_queue
      while (msg = @message_queue.pop(:non_block)) # FIXME: EOFError
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
'.freeze
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
    # @return [Service]
    def request_service(name)
      # Use RequestName, but asynchronously!
      # A synchronous call would not work with service activation, where
      # method calls to be serviced arrive before the reply for RequestName
      # (Ticket#29).
      proxy.RequestName(name, NAME_FLAG_REPLACE_EXISTING) do |rmsg, r|
        # check and report errors first
        raise rmsg if rmsg.is_a?(Error)
        raise NameRequestError unless r == REQUEST_NAME_REPLY_PRIMARY_OWNER
      end
      @service = Service.new(name, self)
      @service
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
    # Send a message _m_ on to the bus. This is done synchronously, thus
    # the call will block until a reply message arrives.
    def send_sync(m, &retc) # :yields: reply/return message
      return if m.nil? # check if somethings wrong
      @message_queue.push(m)
      @method_call_msgs[m.serial] = m
      @method_call_replies[m.serial] = retc

      retm = wait_for_message
      return if retm.nil? # check if somethings wrong

      process(retm)
      while @method_call_replies.key? m.serial
        retm = wait_for_message
        process(retm)
      end
    end

    # @api private
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
      DBus.logger.debug "#{@signal_matchrules.size} rules, adding #{mrs.inspect}"
      # don't ask for the same match if we override it
      unless @signal_matchrules.key?(mrs)
        DBus.logger.debug "Asked for a new match"
        proxy.AddMatch(mrs)
      end
      @signal_matchrules[mrs] = slot
    end

    def remove_match(mr)
      mrs = mr.to_s
      rule_existed = @signal_matchrules.delete(mrs).nil?
      # don't remove nonexisting matches.
      return if rule_existed
      # FIXME: if we do try, the Error.MatchRuleNotFound is *not* raised
      # and instead is reported as "no return code for nil"
      proxy.RemoveMatch(mrs)
    end

    # @api private
    # Process a message _m_ based on its type.
    def process(m)
      return if m.nil? # check if somethings wrong
      case m.message_type
      when Message::ERROR, Message::METHOD_RETURN
        raise InvalidPacketException if m.reply_serial.nil?
        mcs = @method_call_replies[m.reply_serial]
        if !mcs
          DBus.logger.debug "no return code for mcs: #{mcs.inspect} m: #{m.inspect}"
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
          DBus.logger.debug "Got method call on /org/freedesktop/DBus"
        end
        node = @service.get_node(m.path)
        if !node
          reply = Message.error(m, "org.freedesktop.DBus.Error.UnknownObject",
                                "Object #{m.path} doesn't exist")
          @message_queue.push(reply)
        # handle introspectable as an exception:
        elsif m.interface == "org.freedesktop.DBus.Introspectable" &&
              m.member == "Introspect"
          reply = Message.new(Message::METHOD_RETURN).reply_to(m)
          reply.sender = @unique_name
          reply.add_param(Type::STRING, node.to_xml)
          @message_queue.push(reply)
        else
          obj = node.object
          return if obj.nil? # FIXME, pushes no reply
          obj.dispatch(m) if obj
        end
      when DBus::Message::SIGNAL
        # the signal can match multiple different rules
        # clone to allow new signale handlers to be registered
        @signal_matchrules.dup.each do |mrs, slot|
          if DBus::MatchRule.new.from_s(mrs).match(m)
            slot.call(m)
          end
        end
      else
        DBus.logger.debug "Unknown message type: #{m.message_type}"
      end
    rescue Exception => ex
      raise m.annotate_exception(ex)
    end

    # Retrieves the Service with the given _name_.
    # @return [Service]
    def service(name)
      # The service might not exist at this time so we cannot really check
      # anything
      Service.new(name, self)
    end
    alias [] service

    # @api private
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
      @service = Service.new(@unique_name, self)
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
      super(self.class.session_bus_address)
      send_hello
    end

    def self.session_bus_address
      ENV["DBUS_SESSION_BUS_ADDRESS"] ||
        address_from_file ||
        "launchd:env=DBUS_LAUNCHD_SESSION_BUS_SOCKET"
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

  # = Main event loop class.
  #
  # Class that takes care of handling message and signal events
  # asynchronously.  *Note:* This is a native implement and therefore does
  # not integrate with a graphical widget set main loop.
  class Main
    # Create a new main event loop.
    def initialize
      @buses = {}
      @quitting = false
    end

    # Add a _bus_ to the list of buses to watch for events.
    def <<(bus)
      @buses[bus.message_queue.socket] = bus
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
        while (m = b.message_queue.message_from_buffer_nonblock)
          b.process(m)
        end
      end
      while !@quitting && !@buses.empty?
        ready = IO.select(@buses.keys, [], [], 5) # timeout 5 seconds
        next unless ready # timeout exceeds so continue unless quitting
        ready.first.each do |socket|
          b = @buses[socket]
          begin
            b.message_queue.buffer_from_socket_nonblock
          rescue EOFError, SystemCallError
            @buses.delete socket # this bus died
            next
          end
          while (m = b.message_queue.message_from_buffer_nonblock)
            b.process(m)
          end
        end
      end
    end
  end # class Main
end # module DBus
