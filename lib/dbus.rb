# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require_relative "dbus/api_options"
require_relative "dbus/auth"
require_relative "dbus/bus"
require_relative "dbus/core_ext/class/attribute"
require_relative "dbus/error"
require_relative "dbus/export"
require_relative "dbus/introspect"
require_relative "dbus/logger"
require_relative "dbus/marshall"
require_relative "dbus/matchrule"
require_relative "dbus/message"
require_relative "dbus/message_queue"
require_relative "dbus/proxy_object"
require_relative "dbus/proxy_object_factory"
require_relative "dbus/proxy_object_interface"
require_relative "dbus/type"
require_relative "dbus/xml"

require "socket"
require "thread"

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus
  # Default socket name for the system bus.
  SystemSocketName = "unix:path=/var/run/dbus/system_bus_socket"

  # Byte signifying big endianness.
  BIG_END = ?B
  # Byte signifying little endianness.
  LIL_END = ?l

  # Byte signifying the host's endianness.
  HOST_END = if [0x01020304].pack("L").unpack("V")[0] == 0x01020304
    LIL_END
  else
    BIG_END
  end

  # General exceptions.

  # Exception raised when an invalid packet is encountered.
  class InvalidPacketException < Exception
  end

  # Exception raised when there is a problem with a type (may be unknown or
  # mismatch).
  class TypeException < Exception
  end

  # Exception raised when an unmarshalled buffer is truncated and
  # incomplete.
  class IncompleteBufferException < Exception
  end

  # Exception raised when a method has not been implemented (yet).
  class MethodNotImplemented < Exception
  end

  # Exception raised when a method is invoked with invalid
  # parameters (wrong number or type).
  class InvalidParameters < Exception
  end

  # Exception raised when an invalid method name is used.
  class InvalidMethodName < Exception
  end

  # Exception raised when invalid introspection data is parsed/used.
  class InvalidIntrospectionData < Exception
  end
end # module DBus
