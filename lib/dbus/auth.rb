# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

require "rbconfig"

module DBus
  # Exception raised when authentication fails somehow.
  class AuthenticationFailed < StandardError
  end

  # The Authentication Protocol.
  # https://dbus.freedesktop.org/doc/dbus-specification.html#auth-protocol
  #
  # @api private
  module Authentication
    # Base class of authentication mechanisms
    class Mechanism
      # @!method call(challenge)
      # @abstract
      # Replies to server *challenge*, or sends an initial response if the challenge is `nil`.
      # @param challenge [String,nil]
      # @return [Array(Symbol,String)] pair [action, response], where
      #   - [:MechContinue, response] caller should send "DATA response" and go to :WaitingForData
      #   - [:MechOk,       response] caller should send "DATA response" and go to :WaitingForOk
      #   - [:MechError,    message]  caller should send "ERROR message" and go to :WaitingForData

      # Uppercase mechanism name, as sent to the server
      # @return [String]
      def name
        self.class.to_s.upcase.sub(/.*::/, "")
      end
    end

    # Anonymous authentication class.
    # https://dbus.freedesktop.org/doc/dbus-specification.html#auth-mechanisms-anonymous
    class Anonymous < Mechanism
      def call(_challenge)
        [:MechOk, "Ruby DBus"]
      end
    end

    # Class for 'external' type authentication.
    # https://dbus.freedesktop.org/doc/dbus-specification.html#auth-mechanisms-external
    class External < Mechanism
      # Performs the authentication.
      def call(_challenge)
        [:MechOk, Process.uid.to_s]
      end
    end

    # Implements the AUTH DBUS_COOKIE_SHA1 mechanism.
    # https://dbus.freedesktop.org/doc/dbus-specification.html#auth-mechanisms-sha
    class DBusCookieSHA1 < Mechanism
      # returns the modules name
      def name
        "DBUS_COOKIE_SHA1"
      end

      # First we are called with nil and we reply with our username.
      # Then we prove that we can read that user's cookie file.
      def call(challenge)
        if challenge.nil?
          require "etc"
          # number of retries we have for auth
          @retries = 1
          return [:MechContinue, Etc.getlogin]
        end

        require "digest/sha1"
        # name of cookie file, id of cookie in file, servers random challenge
        context, id, s_challenge = challenge.split(" ")
        # Random client challenge
        c_challenge = 1.upto(s_challenge.bytesize / 2).map { rand(255).to_s }.join
        # Search cookie file for id
        path = File.join(ENV["HOME"], ".dbus-keyrings", context)
        DBus.logger.debug "path: #{path.inspect}"
        File.foreach(path) do |line|
          if line.start_with?(id)
            # Right line of file, read cookie
            cookie = line.split(" ")[2].chomp
            DBus.logger.debug "cookie: #{cookie.inspect}"
            # Concatenate and encrypt
            to_encrypt = [s_challenge, c_challenge, cookie].join(":")
            sha = Digest::SHA1.hexdigest(to_encrypt)
            # Return response
            response = [:MechOk, "#{c_challenge} #{sha}"]
            return response
          end
        end
        return if @retries <= 0

        # a little rescue magic
        puts "ERROR: Could not auth, will now exit."
        puts "ERROR: Unable to locate cookie, retry in 1 second."
        @retries -= 1
        sleep 1
        call(challenge)
      end
    end

    # = Authentication client class.
    #
    # Class tha performs the actional authentication.
    class Client
      # Create a new authentication client.
      # @param mechs [Array<Class>,nil] custom list of auth Mechanism classes
      def initialize(socket, mechs = nil)
        @socket = socket
        @state = nil
        @auth_list = mechs || [
          External,
          DBusCookieSHA1,
          Anonymous
        ]
      end

      # Start the authentication process.
      # @raise [AuthenticationFailed]
      def authenticate
        send_nul_byte
        next_mechanism
        @state = :Starting
        while @state != :Authenticated
          r = next_state
          return r if !r
        end
        true
      end

      ##########

      private

      ##########

      # The authentication protocol requires a nul byte
      # that may carry credentials.
      # @return [void]
      def send_nul_byte
        if RbConfig::CONFIG["target_os"] =~ /freebsd/
          @socket.sendmsg(0.chr, 0, nil, [:SOCKET, :SCM_CREDS, ""])
        else
          @socket.write(0.chr)
        end
      end

      # encode plain to hex
      def hex_encode(plain)
        return nil if plain.nil?

        plain.unpack1("H*")
      end

      # decode hex to plain
      def hex_decode(encoded)
        [encoded].pack("H*")
      end

      # Send a string to the socket; good place for test mocks.
      def write_line(str)
        DBus.logger.debug "auth_write: #{str.inspect}"
        @socket.write(str)
      end

      # Send *words* to the server as a single CRLF terminated string.
      def send(*words)
        joined = words.compact.join(" ")
        write_line("#{joined}\r\n")
      end

      # Try authentication using the next mechanism.
      def next_mechanism
        raise AuthenticationFailed if @auth_list.empty?

        @mechanism = @auth_list.shift.new
        action, response = @mechanism.call(nil)
        auth_msg = ["AUTH", @mechanism.name, hex_encode(response)]
        DBus.logger.debug ":Starting action: #{action.inspect}"
        send(* auth_msg)
      rescue AuthenticationFailed
        @socket.close
        raise
      end

      # Read data (a buffer) from the bus until CR LF is encountered.
      # Return the buffer without the CR LF characters.
      # @return [Array<String>] received words
      def next_msg
        read_line.chomp.split(" ")
      end

      # Read a line from the socket; good place for test mocks.
      # @return [String] CRLF (\r\n) terminated
      def read_line
        # TODO: probably can simply call @socket.readline
        data = ""
        crlf = "\r\n"
        left = 1024 # 1024 byte, no idea if it's ever getting bigger
        while left.positive?
          buf = @socket.read(left > 1 ? 1 : left)
          break if buf.nil?

          left -= buf.bytesize
          data += buf
          break if data.include? crlf # crlf means line finished, the TCP socket keeps on listening, so we break
        end
        DBus.logger.debug "auth_read: #{data.inspect}"
        data
      end

      #     # Read data (a buffer) from the bus until CR LF is encountered.
      #     # Return the buffer without the CR LF characters.
      #     def next_msg
      #       @socket.readline.chomp.split(" ")
      #     end

      # Try to reach the next state based on the current state.
      def next_state
        msg = next_msg
        if @state == :Starting
          DBus.logger.debug ":Starting msg: #{msg[0].inspect}"
          case msg[0]
          when "OK"
            @state = :WaitingForOk
          when "CONTINUE"
            @state = :WaitingForData
          when "REJECTED" # needed by tcp, unix-path/abstract doesn't get here
            @state = :WaitingForData
          end
        end
        DBus.logger.debug "state: #{@state}"
        case @state
        when :WaitingForData
          DBus.logger.debug ":WaitingForData msg: #{msg[0].inspect}"
          case msg[0]
          when "DATA"
            challenge = hex_decode(msg[1])
            action, response = @mechanism.call(challenge)
            DBus.logger.debug ":WaitingForData/DATA action: #{action.inspect}"
            case action
            when :MechContinue
              send("DATA", hex_encode(response))
              @state = :WaitingForData
            when :MechOk
              send("DATA", hex_encode(response))
              @state = :WaitingForOk
            when :MechError
              send("ERROR", response)
              @state = :WaitingForData
            end
          when "REJECTED"
            next_mechanism
            @state = :WaitingForData
          when "ERROR"
            send("CANCEL")
            @state = :WaitingForReject
          when "OK"
            send("BEGIN")
            @state = :Authenticated
          else
            send("ERROR")
            @state = :WaitingForData
          end
        when :WaitingForOk
          DBus.logger.debug ":WaitingForOk msg: #{msg[0].inspect}"
          case msg[0]
          when "OK"
            send("BEGIN")
            @state = :Authenticated
          when "REJECT"
            next_mechanism
            @state = :WaitingForData
          when "DATA", "ERROR"
            send("CANCEL")
            @state = :WaitingForReject
          else
            send("ERROR")
            @state = :WaitingForOk
          end
        when :WaitingForReject
          DBus.logger.debug ":WaitingForReject msg: #{msg[0].inspect}"
          case msg[0]
          when "REJECT"
            next_mechanism
            @state = :WaitingForOk
          else
            @socket.close
            return false
          end
        end
        true
      end
    end
  end
end
