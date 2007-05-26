# This file is part of the ruby-dbus project
# Copyright (C) 2007 Arnaud Cornet and Paul van Tilburg
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  class MatchRuleException < Exception
  end

  class MatchRule
    FILTERS = [:sender, :interface, :member, :path, :destination, :type]
    attr_accessor :sender, :interface, :member, :path, :destination
    attr_accessor :args
    attr_reader :type

    def type=(t)
      if not ['signal', 'method_call', 'method_return', 'error'].member?(t)
        raise MatchRuleException 
      end
      @type = t
    end

    # Returns a MatchRule string from object eg:
    # "type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='Foo',path='/bar/foo',destination=':452345.34',arg2='bar'"
    def to_s
      FILTERS.select do |sym|
        not method(sym).call.nil?
      end.collect do |sym|
        "#{sym.to_s}='#{method(sym).call}'"
      end.join(",")
    end

    # parse matchadd string and load it in
    def from_s(str)
      s.split(",").each do |eq|
        if eq =~ /^(.*)='([^']*)'$/
          name = $1
          val = $1
          if FILTERS.member?(name.to_sym)
            method(name + "=").call(val)
          else
            raise MatchRuleException 
          end
        end
      end
    end

    def from_signal(intf, signal)
      signal = signal.name unless signal.is_a?(String)
      self.type = "signal"
      self.interface = intf.name
      self.member = signal
      self.path = intf.object.path
      self
    end

    def match(msg)
      if @type
        if {Message::SIGNAL => "signal", Message::METHOD_CALL => "method_call",
          Message::METHOD_RETURN => "method_return",
          Message::ERROR => "error"}[msg.message_type] != @type
          return false
        end
      end
      return false if @interface and @interface != msg.interface
      return false if @member and @member != msg.member
      return false if @path and @path != msg.path
      true
    end
  end
end
