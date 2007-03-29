# dbus.rb - Module containing the low-level D-Bus implementation
#
# Copyright (C) 2007 Arnaud Cornet, Paul van Tilburg
#
# FIXME: license 

require 'dbus/type'
require 'dbus/introspect'
#require 'dbus/export'
require 'dbus/bus.rb'
require 'dbus/marshall'
require 'dbus/message'
require 'dbus/matchrule'

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

  # Byte signifying the host endianness
  HOST_END = if [0x01020304].pack("L").unpack("V")[0] == 0x01020304
    LIL_END
  else
    BIG_END
  end

  # Exception raised when an invalid packet is encountered.
  class InvalidPacketException < Exception
  end

  # Exception raised when there is a problem with a type (may be unknown or mismatch).
  class TypeException < Exception
  end

  # Exception raised when an unmarshalled buffer is truncated and incomplete
  class IncompleteBufferException < Exception
  end

  class InterfaceNotImplemented < Exception
  end

  class MethodNotInInterface < Exception
  end

  class MethodNotImplemented < Exception
  end

  class InvalidParameters < Exception
  end

  class InvalidMethodName < Exception
  end

  class InvalidIntrospectionData < Exception
  end
end # module DBus
