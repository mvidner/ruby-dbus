# loop.rb - Main Loop
#
# This file is part of the ruby-dbus project
# Copyright (C) 2011 Martin Vidner
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
    class << self
      attr_accessor :default_instance
    end
    @default_instance = nil

    # Create a new main event loop.
    def initialize
      @sockets = Hash.new # Socket => block(Socket)
      @quit_pipe_reader, @quit_pipe_writer = IO.pipe
    end

    # Add a _connection_ to the list of where to watch for events.
    def <<(connection)
      @sockets[connection.connection_queue.socket] = connection
      add(connection.connection_queue.socket) do |socket|
        connection.dispatch_connection_queue
      end
    end

    def add(socket, &handler)
      @sockets[socket] = handler
    end

    # Quit a running main loop, to be used eg. from a signal handler
    def quit
      @quit_pipe_writer.close
    end

    # Run the main loop. This is a blocking call!
    def run
      loop do
        watch_to_read = @sockets.keys << @quit_pipe_reader
        # errors? dbus disconnection is abnormal
        ready_to_read, dummy, dummy = IO.select(watch_to_read)
        break if ready_to_read.include? @quit_pipe_reader

        ready_to_read.each do |socket|
          @sockets[socket].call(socket)
        end
      end
    end
  end # class Main

  # run the default main loop, over all existing `DBus::Connection`s
  def main
    fail "Default main loop already running" unless DBus::Main.default_instance.nil?
    DBus::Main.default_instance = DBus::Main.new
    ObjectSpace.each_object(DBus::Connection) { |c| DBus::Main.default_instance << c }
    DBus::Main.default_instance.run
  end
  module_function :main

  # quit the default main loop and forget it
  def main_quit
    DBus::Main.default_instance.quit
    DBus::Main.default_instance = nil
  end
  module_function :main_quit
end
