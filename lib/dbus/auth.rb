# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

$debug = $DEBUG #it's all over the state machine

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
      return Process.uid.to_s.split(//).collect { |a| "%x" % a[0].ord }.join
    end
  end
  
  # = Authentication class using SHA1 crypto algorithm 
  #
  # Class for 'CookieSHA1' type authentication.
  # Implements the AUTH DBUS_COOKIE_SHA1 mechanism.
  class DBusCookieSHA1 < Authenticator
        
    #the autenticate method (called in stage one of authentification)    
    def authenticate
      require 'etc'
      #number of retries we have for auth
      @retries = 1
      return "#{hex_encode(Etc.getlogin)}" #server expects it to be binary
    end

    #returns the modules name
    def name
      return 'DBUS_COOKIE_SHA1'
    end
    
    #handles the interesting crypto stuff, check the rbus-project for more info: http://rbus.rubyforge.org/
    def data(hexdata)
      require 'digest/sha1'
      data = hex_decode(hexdata)
      # name of cookie file, id of cookie in file, servers random challenge  
      context, id, s_challenge = data.split(' ')
      # Random client challenge        
      c_challenge = Array.new(s_challenge.bytesize/2).map{|obj|obj=rand(255).to_s}.join
      # Search cookie file for id
      path = File.join(ENV['HOME'], '.dbus-keyrings', context)
      puts "DEBUG: path: #{path.inspect}" if $debug
      File.foreach(path) do |line|
        if line.index(id) == 0
          # Right line of file, read cookie
          cookie = line.split(' ')[2].chomp
          puts "DEBUG: cookie: #{cookie.inspect}" if $debug
          # Concatenate and encrypt
          to_encrypt = [s_challenge, c_challenge, cookie].join(':')
          sha = Digest::SHA1.hexdigest(to_encrypt)
          #the almighty tcp server wants everything hex encoded
          hex_response = hex_encode("#{c_challenge} #{sha}")
          # Return response
          response = [:AuthOk, hex_response]
          return response
        end
      end
      #a little rescue magic
      unless @retries <= 0
        puts "ERROR: Could not auth, will now exit." 
        puts "ERROR: Unable to locate cookie, retry in 1 second."
        @retries -= 1
        sleep 1
        data(hexdata)
      end
    end  
    
    # encode plain to hex
    def hex_encode(plain)
      return nil if plain.nil?
      plain.to_s.unpack('H*')[0]
    end
    
    # decode hex to plain
    def hex_decode(encoded)
      encoded.scan(/[[:xdigit:]]{2}/).map{|h|h.hex.chr}.join
    end  
  end #DBusCookieSHA1 class ends here

  # Note: this following stuff is tested with External authenticator only!

  # = Authentication client class.
  #
  # Class tha performs the actional authentication.
  class Client
    # Create a new authentication client.
    def initialize(socket)
      @socket = socket
      @state = nil
      @auth_list = [External,DBusCookieSHA1]
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
      begin
        raise AuthException if @auth_list.size == 0
        @authenticator = @auth_list.shift.new
        auth_msg = ["AUTH", @authenticator.name, @authenticator.authenticate]
        puts "DEBUG: auth_msg: #{auth_msg.inspect}" if $debug
        send(auth_msg)
      rescue AuthException
        @socket.close
        raise
      end
    end

    # Read data (a buffer) from the bus until CR LF is encountered.
    # Return the buffer without the CR LF characters.
    def next_msg
      data,crlf = "","\r\n"
      left = 1024 #1024 byte, no idea if it's ever getting bigger
      while left > 0
        buf = @socket.read( left > 1 ? 1 : left )
        break if buf.nil?
        left -= buf.bytesize
        data += buf
        break if data.include? crlf #crlf means line finished, the TCP socket keeps on listening, so we break 
      end
      readline = data.chomp.split(" ")
      puts "DEBUG: readline: #{readline.inspect}" if $debug
      return readline
    end

=begin
    # Read data (a buffer) from the bus until CR LF is encountered.
    # Return the buffer without the CR LF characters.
    def next_msg
      @socket.readline.chomp.split(" ")
    end
=end

    # Try to reach the next state based on the current state.
    def next_state
      msg = next_msg
      if @state == :Starting
        puts "DEBUG: :Starting msg: #{msg[0].inspect}" if $debug
        case msg[0]
        when "OK"
          @state = :WaitingForOk    
        when "CONTINUE"
          @state = :WaitingForData
        when "REJECTED" #needed by tcp, unix-path/abstract doesn't get here
          @state = :WaitingForData
        end
      end
      puts "DEBUG: state: #{@state}" if $debug
      case @state
      when :WaitingForData
        puts "DEBUG: :WaitingForData msg: #{msg[0].inspect}" if $debug
        case msg[0]
        when "DATA"
          chall = msg[1]
          resp, chall = @authenticator.data(chall)
          puts "DEBUG: :WaitingForData/DATA resp: #{resp.inspect}" if $debug
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
        puts "DEBUG: :WaitingForOk msg: #{msg[0].inspect}" if $debug
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
        puts "DEBUG: :WaitingForReject msg: #{msg[0].inspect}" if $debug
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
