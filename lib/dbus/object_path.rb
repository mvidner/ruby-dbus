# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2019 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # A {::String} that validates at initialization time.
  # See also {DBus::Data::ObjectPath}
  # @see https://dbus.freedesktop.org/doc/dbus-specification.html#message-protocol-marshaling-object-path
  class ObjectPath < String
    # @raise Error if not a valid object path
    def initialize(str)
      unless self.class.valid?(str)
        raise DBus::Error, "Invalid object path #{str.inspect}"
      end

      super
    end

    def self.valid?(str)
      str == "/" || str =~ %r{\A(/[A-Za-z0-9_]+)+\z}
    end
  end
end
