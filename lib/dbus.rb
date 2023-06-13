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

module DBus
  # Protocol character signifying big endianness.
  BIG_END = "B"
  # Protocol character signifying little endianness.
  LIL_END = "l"

  # Protocol character signifying the host's endianness.
  # "S": unpack as uint16, native endian
  HOST_END = { 1 => BIG_END, 256 => LIL_END }.fetch("\x00\x01".unpack1("S"))
end
# ^ That's because dbus/message needs HOST_END early

require_relative "dbus/api_options"
require_relative "dbus/auth"
require_relative "dbus/bus"
require_relative "dbus/bus_name"
require_relative "dbus/connection"
require_relative "dbus/data"
require_relative "dbus/emits_changed_signal"
require_relative "dbus/error"
require_relative "dbus/introspect"
require_relative "dbus/logger"
require_relative "dbus/main"
require_relative "dbus/marshall"
require_relative "dbus/matchrule"
require_relative "dbus/message"
require_relative "dbus/message_queue"
require_relative "dbus/node_tree"
require_relative "dbus/object"
require_relative "dbus/object_manager"
require_relative "dbus/object_path"
require_relative "dbus/object_server"
require_relative "dbus/platform"
require_relative "dbus/proxy_object"
require_relative "dbus/proxy_object_factory"
require_relative "dbus/proxy_object_interface"
require_relative "dbus/proxy_service"
require_relative "dbus/raw_message"
require_relative "dbus/type"
require_relative "dbus/xml"

require "socket"
# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # Comparing symbols is faster than strings
  # @return [:little,:big]
  HOST_ENDIANNESS = RawMessage.endianness(HOST_END)

  # General exceptions.

  # Exception raised when there is a problem with a type (may be unknown or
  # mismatch).
  class TypeException < Exception
  end

  # Exception raised when an unmarshalled buffer is truncated and
  # incomplete.
  class IncompleteBufferException < Exception
  end

  # Exception raised when an invalid method name is used.
  # FIXME: use NameError
  class InvalidMethodName < Exception
  end

  # Exception raised when invalid introspection data is parsed/used.
  class InvalidIntrospectionData < Exception
  end
end
