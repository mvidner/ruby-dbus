# error.rb
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # Represents a D-Bus Error, both on the client and server side.
  class Error < StandardError
    # error_name. +message+ is inherited from +Exception+
    attr_reader :name
    # for received errors, the raw D-Bus message
    attr_reader :dbus_message

    # If +msg+ is a +DBus::Message+, its contents is used for initialization.
    # Otherwise, +msg+ is taken as a string and +name+ is used.
    def initialize(msg, name = "org.freedesktop.DBus.Error.Failed")
      if msg.is_a? DBus::Message
        @dbus_message = msg
        @name = msg.error_name
        super(msg.params[0]) # or nil
        if msg.params[1].is_a? Array
          set_backtrace msg.params[1]
        end
      else
        @name = name
        super(msg)
      end
      # TODO validate error name
    end
  end # class Error

  # raise DBus.error, "message"
  # raise DBus.error("org.example.Error.SeatOccupied"), "Seat #{n} is occupied"
  def error(name = "org.freedesktop.DBus.Error.Failed")
    # message will be set by Kernel.raise
    DBus::Error.new(nil, name)
  end
  module_function :error
end # module DBus
