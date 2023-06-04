# frozen_string_literal: true

# dbus/logger.rb - debug logging
#
# This file is part of the ruby-dbus project
# Copyright (C) 2012 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "logger"

module DBus
  # Get the logger for the DBus module.
  # The default one logs to STDERR,
  # with DEBUG if $DEBUG is set, otherwise INFO.
  def logger
    if @logger.nil?
      debug = $DEBUG || ENV["RUBY_DBUS_DEBUG"]
      @logger = Logger.new($stderr)
      @logger.level = debug ? Logger::DEBUG : Logger::INFO
    end
    @logger
  end
  module_function :logger

  # Set the logger for the DBus module
  def logger=(logger)
    @logger = logger
  end
  module_function :logger=
end
