# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

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

    # A variant of EXTERNAL that doesn't say our UID.
    # Seen busctl do this and it worked across a container boundary.
    class ExternalWithoutUid < External
      def name
        "EXTERNAL"
      end

      def call(_challenge)
        [:MechContinue, nil]
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

    # Declare client state transitions, for ease of code reading.
    # It is just a pair.
    NextState = Struct.new(:state, :command_words)

    # Authenticates the connection before messages can be exchanged.
    class Client
      # @return [Boolean] have we negotiated Unix file descriptor passing
      # NOTE: not implemented yet in upper layers
      attr_reader :unix_fd

      # @return [String]
      attr_reader :address_uuid

      # Create a new authentication client.
      # @param mechs [Array<Mechanism,Class>,nil] custom list of auth Mechanism objects or classes
      def initialize(socket, mechs = nil)
        @unix_fd = false
        @address_uuid = nil

        @socket = socket
        @state = nil
        @auth_list = mechs || [
          External,
          DBusCookieSHA1,
          ExternalWithoutUid,
          Anonymous
        ]
      end

      # Start the authentication process.
      # @return [void]
      # @raise [AuthenticationFailed]
      def authenticate
        DBus.logger.debug "Authenticating"
        send_nul_byte

        use_next_mechanism

        @state, command = next_state_via_mechanism.to_a
        send(command)

        loop do
          DBus.logger.debug "auth STATE: #{@state}"
          words = next_msg

          @state, command = next_state(words).to_a
          break if [:TerminatedOk, :TerminatedError].include? @state

          send(command)
        end

        raise AuthenticationFailed, command.first if @state == :TerminatedError

        send("BEGIN")
      end

      ##########

      private

      ##########

      # The authentication protocol requires a nul byte
      # that may carry credentials.
      # @return [void]
      def send_nul_byte
        if Platform.freebsd?
          @socket.sendmsg(0.chr, 0, nil, [:SOCKET, :SCM_CREDS, ""])
        else
          @socket.write(0.chr)
        end
      end

      # encode plain to hex
      # @param plain [String,nil]
      # @return [String,nil]
      def hex_encode(plain)
        return nil if plain.nil?

        plain.unpack1("H*")
      end

      # decode hex to plain
      # @param encoded [String,nil]
      # @return [String,nil]
      def hex_decode(encoded)
        return nil if encoded.nil?

        [encoded].pack("H*")
      end

      # Send a string to the socket; good place for test mocks.
      def write_line(str)
        DBus.logger.debug "auth_write: #{str.inspect}"
        @socket.write(str)
      end

      # Send *words* to the server as a single CRLF terminated string.
      # @param words [Array<String>,String]
      def send(words)
        joined = Array(words).compact.join(" ")
        write_line("#{joined}\r\n")
      end

      # Try authentication using the next mechanism.
      # @raise [AuthenticationFailed] if there are no more left
      # @return [void]
      def use_next_mechanism
        raise AuthenticationFailed, "Authentication mechanisms exhausted" if @auth_list.empty?

        @mechanism = @auth_list.shift
        @mechanism = @mechanism.new if @mechanism.is_a? Class
      rescue AuthenticationFailed
        # TODO: make this caller's responsibility
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

      # @param hex_challenge [String,nil] (nil when the server said "DATA\r\n")
      # @param use_data [Boolean] say DATA instead of AUTH
      # @return [NextState]
      def next_state_via_mechanism(hex_challenge = nil, use_data: false)
        challenge = hex_decode(hex_challenge)

        action, response = @mechanism.call(challenge)
        DBus.logger.debug "auth mechanism action: #{action.inspect}"

        command = use_data ? ["DATA"] : ["AUTH", @mechanism.name]

        case action
        when :MechError
          NextState.new(:WaitingForData, ["ERROR", response])
        when :MechContinue
          NextState.new(:WaitingForData, command + [hex_encode(response)])
        when :MechOk
          NextState.new(:WaitingForOk, command + [hex_encode(response)])
        else
          raise AuthenticationFailed, "internal error, unknown action #{action.inspect} " \
                                      "from our mechanism #{@mechanism.inspect}"
        end
      end

      # Try to reach the next state based on the current state.
      # @param received_words [Array<String>]
      # @return [NextState]
      def next_state(received_words)
        msg = received_words

        case @state
        when :WaitingForData
          case msg[0]
          when "DATA"
            next_state_via_mechanism(msg[1], use_data: true)
          when "REJECTED"
            use_next_mechanism
            next_state_via_mechanism
          when "ERROR"
            NextState.new(:WaitingForReject, ["CANCEL"])
          when "OK"
            @address_uuid = msg[1]
            # NextState.new(:TerminatedOk, [])
            NextState.new(:WaitingForAgreeUnixFD, ["NEGOTIATE_UNIX_FD"])
          else
            NextState.new(:WaitingForData, ["ERROR"])
          end
        when :WaitingForOk
          case msg[0]
          when "OK"
            @address_uuid = msg[1]
            # NextState.new(:TerminatedOk, [])
            NextState.new(:WaitingForAgreeUnixFD, ["NEGOTIATE_UNIX_FD"])
          when "REJECTED"
            use_next_mechanism
            next_state_via_mechanism
          when "DATA", "ERROR"
            NextState.new(:WaitingForReject, ["CANCEL"])
          else
            # we don't understand server's response but still wait for a successful auth completion
            NextState.new(:WaitingForOk, ["ERROR"])
          end
        when :WaitingForReject
          case msg[0]
          when "REJECTED"
            use_next_mechanism
            next_state_via_mechanism
          else
            # TODO: spec says to close socket, clarify
            NextState.new(:TerminatedError, ["Unknown server reply #{msg[0].inspect} when expecting REJECTED"])
          end
        when :WaitingForAgreeUnixFD
          case msg[0]
          when "AGREE_UNIX_FD"
            @unix_fd = true
            NextState.new(:TerminatedOk, [])
          when "ERROR"
            @unix_fd = false
            NextState.new(:TerminatedOk, [])
          else
            # TODO: spec says to close socket, clarify
            NextState.new(:TerminatedError, ["Unknown server reply #{msg[0].inspect} to NEGOTIATE_UNIX_FD"])
          end
        else
          raise "Internal error: unhandled state #{@state.inspect}"
        end
      end
    end
  end
end
