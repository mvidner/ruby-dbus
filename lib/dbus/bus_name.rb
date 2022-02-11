# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2019 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # A {::String} that validates at initialization time
  # @see https://dbus.freedesktop.org/doc/dbus-specification.html#message-protocol-names-bus
  class BusName < String
    # @raise Error if not a valid bus name
    def initialize(s)
      unless self.class.valid?(s)
        raise DBus::Error, "Invalid bus name #{s.inspect}"
      end

      super
    end

    def self.valid?(s)
      s.size <= 255 &&
        (s =~ /\A:[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+\z/ ||
         s =~ /\A[A-Za-z_-][A-Za-z0-9_-]*(\.[A-Za-z_-][A-Za-z0-9_-]*)+\z/)
    end
  end
end
