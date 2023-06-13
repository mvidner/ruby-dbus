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

require_relative "connection"

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # A regular Bus {Connection}.
  # As opposed to a peer connection to a single counterparty with no daemon in between.
  class BusConnection < Connection
    # The unique name (by specification) of the message.
    attr_reader :unique_name

    # Connect, authenticate, and send Hello.
    # @param addresses [String]
    # @see https://dbus.freedesktop.org/doc/dbus-specification.html#addresses
    def initialize(addresses)
      super
      @unique_name = nil
      @proxy = nil
      send_hello
    end

    # Set up a ProxyObject for the bus itself, since the bus is introspectable.
    # @return [ProxyObject] that always returns an array
    #   ({DBus::ApiOptions#proxy_method_returns_array})
    # Returns the object.
    def proxy
      if @proxy.nil?
        xml_filename = File.expand_path("org.freedesktop.DBus.xml", __dir__)
        xml = File.read(xml_filename)

        path = "/org/freedesktop/DBus"
        dest = "org.freedesktop.DBus"
        pof = DBus::ProxyObjectFactory.new(
          xml, self, dest, path,
          api: ApiOptions::A0
        )
        @proxy = pof.build["org.freedesktop.DBus"]
      end
      @proxy
    end

    # Request a well-known name so that clients can find us.
    # @note Parameters other than *name* are advanced, you probably don't need them.
    #
    # With no boolean flags, running a second instance of a program that calls `request_name`
    # will result in the second one failing, which this library translates to an exception.
    # If you want the second instance to take over, you need both
    # `allow_replacement: true` and `replace_existing: true.`
    #
    # @param name [BusName] the requested name
    # @param replace_existing [Boolean]
    #   Replace an existing owner of the name, if that owner set *allow_replacement*.
    # @param allow_replacement [Boolean]
    #   Other connections that specify *replace_existing* will be able to take
    #   the name from us. We will get {#on_name_lost NameLost}. If we specified *queue*
    #   we may get the name again, with {#on_name_acquired NameAcquired}.
    # @param queue [Boolean]
    #   Affects the behavior when the bus denies the name (sooner or later).
    #   - If `false` (default), it is recommended to let the `NameRequestError` fall through and end your program.
    #   - If `true`, you should `rescue` the `NameRequestError` and set up
    #     {#on_name_acquired NameAcquired} and {#on_name_lost NameLost} handlers.
    #     Meanwhile, the bus will put us in a queue waiting for *name* (this is the "sooner" case).
    #     Also, if we had `allow_replacement: true`, another connection can cause us
    #     to lose the name. We will be moved back to the queue, waiting for when the other owners give up
    #     (the "later" case).
    # @param flags [Integer,nil]
    #    If specified, overrides the boolean parameters.
    #    Use a bitwise sum `|` of:
    #    -  NAME_FLAG_ALLOW_REPLACEMENT
    #    -  NAME_FLAG_REPLACE_EXISTING
    #    -  NAME_FLAG_DO_NOT_QUEUE
    #    Note that `0` implies `queue: true`.
    #
    # @return [REQUEST_NAME_REPLY_PRIMARY_OWNER,REQUEST_NAME_REPLY_ALREADY_OWNER] on success
    # @raise [NameRequestError] with #error_code REQUEST_NAME_REPLY_EXISTS or REQUEST_NAME_REPLY_IN_QUEUE, on failure
    # @raise DBus::Error another way to fail is being prohibited to own the name
    #   which is the default on the system bus
    #
    # @see https://dbus.freedesktop.org/doc/dbus-specification.html#bus-messages-request-name
    #
    # @example Simple usage
    #   bus = DBus.session_bus
    #   bus.object_server.export(DBus::Object.new("/org/example/Test"))
    #   bus.request_name("org.example.Test")
    #   # main loop
    #
    # @example Second instance taking over
    #   bus = DBus.session_bus
    #   bus.object_server.export(DBus::Object.new("/org/example/Test"))
    #   bus.on_name_lost { exit }
    #   bus.request_name("org.example.Test", allow_replacement: true, replace_existing: true)
    #   # main loop
    #
    # @example Second instance waiting for its turn
    #   bus = DBus.session_bus
    #   bus.object_server.export(DBus::Object.new("/org/example/Test"))
    #   bus.on_name_acquired { @owner = true }
    #   begin
    #     bus.request_name("org.example.Test", queue: true)
    #   rescue DBus::Connection::NameRequestError => e
    #     @owner = false
    #   end
    #   # main loop
    def request_name(name,
                     allow_replacement: false,
                     replace_existing: false,
                     queue: false,
                     flags: nil)
      if flags.nil?
        flags = (allow_replacement ? NAME_FLAG_ALLOW_REPLACEMENT : 0) |
                (replace_existing ? NAME_FLAG_REPLACE_EXISTING : 0) |
                (queue ? 0 : NAME_FLAG_DO_NOT_QUEUE)
      end
      name = BusName.new(name)
      r = proxy.RequestName(name, flags).first
      handle_return_of_request_name(r, name)
    end

    # The caller has released his claim on the given name.
    # Either the caller was the primary owner of the name, and the name is now unused
    #   or taken by somebody waiting in the queue for the name,
    # or the caller was waiting in the queue for the name and has now been removed from the queue.
    RELEASE_NAME_REPLY_RELEASED = 1
    # The given name does not exist on this bus.
    RELEASE_NAME_REPLY_NON_EXISTENT = 2
    # The caller was not the primary owner of this name, and was also not waiting in the queue to own this name.
    RELEASE_NAME_REPLY_NOT_OWNER = 3

    # @param name [BusName] the name to release
    def release_name(name)
      name = BusName.new(name)
      proxy.ReleaseName(name).first
    end

    def on_name_acquired(&handler)
      proxy.on_signal("NameAcquired", &handler)
    end

    def on_name_lost(&handler)
      proxy.on_signal("NameLost", &handler)
    end

    # Asks bus to send us messages matching mr, and execute slot when
    # received
    # @param match_rule [MatchRule,#to_s]
    # @return [void]
    def add_match(match_rule, &slot)
      mrs = match_rule.to_s
      rule_existed = super(mrs, &slot)
      # don't ask for the same match if we override it
      return if rule_existed

      DBus.logger.debug "Asked for a new match"
      proxy.AddMatch(mrs)
    end

    # @param match_rule [MatchRule,#to_s]
    # @return [void]
    def remove_match(match_rule)
      mrs = match_rule.to_s
      rule_existed = super(mrs)
      # don't remove nonexisting matches.
      return if rule_existed

      # FIXME: if we do try, the Error.MatchRuleNotFound is *not* raised
      # and instead is reported as "no return code for nil"
      proxy.RemoveMatch(mrs)
    end

    # Makes a {ProxyService} with the given *name*.
    # Note that this succeeds even if the name does not exist and cannot be
    # activated. It will only fail when calling a method.
    # @return [ProxyService]
    def service(name)
      # The service might not exist at this time so we cannot really check
      # anything
      ProxyService.new(name, self)
    end
    alias [] service

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
  # @deprecated just use BusConnection
  class RemoteBus < BusConnection
  end

  # See ASystemBus
  class SystemBus < ASystemBus
    include Singleton
  end

  # Shortcut for the {SystemBus} instance
  # @return [BusConnection]
  def self.system_bus
    SystemBus.instance
  end

  # Shortcut for the {SessionBus} instance
  # @return [BusConnection]
  def self.session_bus
    SessionBus.instance
  end
end
