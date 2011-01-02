# cq.rb - Connection Queue
#
# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require 'socket'
require 'thread'
require 'singleton'
require 'fcntl'

# = D-Bus main module
#
# Module containing all the D-Bus modules and classes.
module DBus

  # Translates between a socket and Message objects
  class ConnectionQueue
    # The socket that is used to connect with the bus.
    attr_reader :socket
    # Method called on EOF
    attr_accessor :rescuemethod

    def initialize(address, threaded)
      @address = address
      @threaded = threaded
      @buffer = ""
      @is_tcp = false
      @rescuemethod = nil
      connect                   # initializes @socket
      # @client - unneeded? should be a local var
    end

    # TODO failure modes
    #
    # If _non_block_ is true, return nil instead of waiting
    # (not used, just for Queue compatibility)
    def pop(non_block = false)
      buffer_from_socket_nonblock
      msg = message_from_buffer_nonblock
      if non_block
        return msg
      end
      # we can block
      while msg.nil?
        r, d, d = IO.select([@socket])
        if r and r[0] == @socket
          buffer_from_socket_nonblock
          msg = message_from_buffer_nonblock
        end
      end
      msg
    end

    def push(message)
      @socket.write(message.marshall)
    end
    alias :<< :push

    private

    # Connect to the bus and initialize the connection.
    def connect
      addresses = @address.split ";"
      # connect to first one that succeeds
      worked = addresses.find do |a|
        transport, keyvaluestring = a.split ":"
        kv_list = keyvaluestring.split ","
        kv_hash = Hash.new
        kv_list.each do |kv|
          key, escaped_value = kv.split "="
          value = escaped_value.gsub(/%(..)/) {|m| [$1].pack "H2" }
          kv_hash[key] = value
        end
        case transport
        when "unix"
          connect_to_unix kv_hash
        when "tcp"
          connect_to_tcp kv_hash
        else
          # ignore, report?
        end
      end
      if @threaded
        start_read_thread
      end
      worked
      # returns the address that worked or nil.
      # how to report failure?
    end

    # Connect to a bus over tcp and initialize the connection.
    def connect_to_tcp(params)
      #check if the address is sufficient
      if params.key?("host") and params.key?("port")
        begin
          #initialize the tcp socket
          @socket = TCPSocket.new(params["host"],params["port"].to_i)
          @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
          init_connection
          @is_tcp = true
        end
      else
        #Danger, Will Robinson: the specified "address" is not usable
        puts "Error: supplied address: #{@address}, unusable! sorry."
      end
    end

    # Connect to an abstract unix bus and initialize the connection.
    def connect_to_unix(params)
      @socket = Socket.new(Socket::Constants::PF_UNIX,Socket::Constants::SOCK_STREAM, 0)
      @socket.fcntl(Fcntl::F_SETFD, Fcntl::FD_CLOEXEC)
      if ! params['abstract'].nil?
        if HOST_END == LIL_END
          sockaddr = "\1\0\0#{params['abstract']}"
        else
          sockaddr = "\0\1\0#{params['abstract']}"
        end
      elsif ! params['path'].nil?
        sockaddr = Socket.pack_sockaddr_un(params['path'])
      end
      @socket.connect(sockaddr)
      init_connection
    end

    # Initialize the connection to the bus.
    def init_connection
      @client = Client.new(@socket)
      @client.authenticate
    end    

    # Get and remove one message from the buffer.
    # Return the message or nil.
    # FIXME poll implies waiting, rename to _non_block
    def message_from_buffer_nonblock
      return nil if @buffer.empty?
      ret = nil
      begin
        ret, size = Message.new.unmarshall_buffer(@buffer)
        @buffer.slice!(0, size)
      rescue IncompleteBufferException => e
        # fall through, let ret be null
      end
      ret
    end

    # Retrieve all the messages that are currently in the buffer.
    def messages
      ret = Array.new
      while msg = message_from_buffer_nonblock
        ret << msg
      end
      ret
    end

    # The buffer size for messages.
    MSG_BUF_SIZE = 4096

    # Fill (append) the buffer from data that might be available on the
    # socket.
    def buffer_from_socket_nonblock
      @buffer += @socket.read_nonblock(MSG_BUF_SIZE)  
    rescue Errno::EAGAIN
      # fine, would block
    rescue EOFError
      if @threaded
        @rescuemethod.call
      end
      raise # the caller expects it
    rescue Exception => e
      puts "Oops:", e
      raise if @is_tcp          # why?
      puts "WARNING: read_nonblock failed, falling back to .recv"
      @buffer += @socket.recv(MSG_BUF_SIZE)  
    end

    # Update the buffer and retrieve all messages using Connection#messages.
    # Return the messages.
    def poll_messages
      ret = nil
      r, d, d = IO.select([@socket], nil, nil, 0)
      if r and r.size > 0
        buffer_from_socket_nonblock
      end
      messages
    end
  end # class ConnectionQueue

end # module DBus
