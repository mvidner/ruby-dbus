# dbus.rb - Module containing the low-level D-Bus implementation
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'dbus/type'
require 'dbus/introspect'
require 'dbus/export'
require 'dbus/bus.rb'
require 'dbus/marshall'
require 'dbus/message'
require 'dbus/matchrule'
require 'dbus/auth'

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

  # Exception raised when an interface is not implemented.
  class InterfaceNotImplemented < Exception
  end

  # Exception raised when an method is not found in the interface.
  class MethodNotInInterface < Exception
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
