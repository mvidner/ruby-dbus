# dbus/logger.rb - debug logging
#
# This file is part of the ruby-dbus project
# Copyright (C) 2012 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'logger'

module DBus
  def logger
    @logger ||= Logger.new(STDERR)
  end

  module_function :logger
end
