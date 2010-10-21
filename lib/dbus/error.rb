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
  # A helper exception on errors
  class Error < Exception
    attr_reader :dbus_message
    def initialize(msg)
      super(msg.error_name + ": " + msg.params.join(", "))
      @dbus_message = msg
    end
  end
end # module DBus
