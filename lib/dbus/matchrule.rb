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
      self.type = "signal"
      self.interface = intf.name
      self.member = signal.name
      self.path = intf.object.path
      self
    end
  end
end
