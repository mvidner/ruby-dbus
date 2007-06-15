# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # Exception raised when authentication fails somehow.
  class AuthenticationFailed < Exception
  end

  # = General class for authentication.
  class Authenticator
    # Returns the name of the authenticator.
    def name
      self.class.to_s.upcase.sub(/.*::/, "")
    end
  end

  # = External authentication class 
  #
  # Class for 'external' type authentication.
  class External < Authenticator
    # Performs the authentication.
    def authenticate
      # Take the user id (eg integer 1000) make a string out of it "1000", take
      # each character and determin hex value "1" => 0x31, "0" => 0x30. You
      # obtain for "1000" => 31303030 This is what the server is expecting.
      # Why? I dunno. How did I come to that conclusion? by looking at rbus
      # code. I have no idea how he found that out.
      return Process.uid.to_s.split(//).collect { |a| "%x" % a[0] }.join
    end
  end

  # Note: this following stuff is tested with External authenticator only!

  # = Authentication client class.
  #
  # Class tha performs the actional authentication.
  class Client
    # Create a new authentication client.
    def initialize(socket)
      @socket = socket
      @state = nil
      @auth_list = [External]
    end

    # Start the authentication process.
    def authenticate
      @socket.write(0.chr)
      next_authenticator
      @state = :Starting
      while @state != :Authenticated
        r = next_state
        return r if not r
      end
      true
    end

    ##########
    private
    ##########

    # Send an authentication method _meth_ with arguments _args_ to the
    # server.
    def send(meth, *args)
      o = ([meth] + args).join(" ")
      @socket.write(o + "\r\n")
    end

    # Try authentication using the next authenticator.
    def next_authenticator
      raise AuthenticationFailed if @auth_list.size == 0
      @authenticator = @auth_list.shift.new
      send("AUTH", @authenticator.name, @authenticator.authenticate)
    end


    # Read data (a buffer) from the bus until CR LF is encountered.
    # Return the buffer without the CR LF characters.
    def next_msg
      @socket.readline.chomp.split(" ")
    end

    # Try to reach the next state based on the current state.
    def next_state
      msg = next_msg
      if @state == :Starting
        case msg[0]
        when "CONTINUE"
          @state = :WaitingForData
        when "OK"
          @state = :WaitingForOk
        end
      end
      case @state
      when :WaitingForData
        case msg[0]
        when "DATA"
          chall = msg[1]
          resp, chall = @authenticator.data(chall)
          case resp
          when :AuthContinue
            send("DATA", chall)
            @state = :WaitingForData
          when :AuthOk
            send("DATA", chall)
            @state = :WaitingForOk
          when :AuthError
            send("ERROR")
            @state = :WaitingForData
          end
        when "REJECTED"
          next_authenticator
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
        case msg[0]
        when "OK"
          send("BEGIN")
          @state = :Authenticated
        when "REJECT"
          next_authenticator
          @state = :WaitingForData
        when "DATA", "ERROR"
          send("CANCEL")
          @state = :WaitingForReject
        else
          send("ERROR")
          @state = :WaitingForOk
        end
      when :WaitingForReject
        case msg[0]
        when "REJECT"
          next_authenticator
          @state = :WaitingForOk
        else
          @socket.close
          return false
        end
      end
      return true
    end # def next_state
  end # class Client
end # module D-Bus
