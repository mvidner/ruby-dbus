# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2023 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "rbconfig"

module DBus
  # Platform detection
  module Platform
    module_function

    def freebsd?
      RbConfig::CONFIG["target_os"] =~ /freebsd/
    end

    def macos?
      RbConfig::CONFIG["target_os"] =~ /darwin/
    end
  end
end
