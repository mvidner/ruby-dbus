# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
# Copyright (C) 2023 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # = Main event loop class.
  #
  # Class that takes care of handling message and signal events
  # asynchronously.  *Note:* This is a native implement and therefore does
  # not integrate with a graphical widget set main loop.
  class Main
    # Create a new main event loop.
    def initialize
      @buses = {}
      @quitting = false
    end

    # Add a _bus_ to the list of buses to watch for events.
    def <<(bus)
      @buses[bus.message_queue.socket] = bus
    end

    # Quit a running main loop, to be used eg. from a signal handler
    def quit
      @quitting = true
    end

    # Run the main loop. This is a blocking call!
    def run
      # before blocking, empty the buffers
      # https://bugzilla.novell.com/show_bug.cgi?id=537401
      @buses.each_value do |b|
        while (m = b.message_queue.message_from_buffer_nonblock)
          b.process(m)
        end
      end
      while !@quitting && !@buses.empty?
        ready = IO.select(@buses.keys, [], [], 5) # timeout 5 seconds
        next unless ready # timeout exceeds so continue unless quitting

        ready.first.each do |socket|
          b = @buses[socket]
          begin
            b.message_queue.buffer_from_socket_nonblock
          rescue EOFError, SystemCallError => e
            DBus.logger.debug "Got #{e.inspect} from #{socket.inspect}"
            @buses.delete socket # this bus died
            next
          end
          while (m = b.message_queue.message_from_buffer_nonblock)
            b.process(m)
          end
        end
      end
      DBus.logger.debug "Main loop quit" if @quitting
      DBus.logger.debug "Main loop quit, no connections left" if @buses.empty?
    end
  end
end
