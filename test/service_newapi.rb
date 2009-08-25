#!/usr/bin/env ruby

require 'dbus'

def d(msg)
  puts msg if $DEBUG
end

class Test < DBus::Object
  # Create an interface aggregating all upcoming dbus_method defines.
  dbus_interface "org.ruby.SampleInterface" do
    dbus_method :hello, "in name:s, in name2:s" do |name, name2|
      puts "hello(#{name}, #{name2})"
    end

    dbus_method :test_variant, "in stuff:v" do |variant|
      p variant
    end

    dbus_method :the_answer, "out answer:i" do
      42
    end

    dbus_signal :SomethingJustHappened, "toto:s, tutu:u"
  end

  dbus_interface "org.ruby.AnotherInterface" do
    dbus_method :ThatsALongMethodNameIThink do
      puts "ThatsALongMethodNameIThink"
    end
    dbus_method :Reverse, "in instr:s, out outstr:s" do |instr|
      outstr = instr.split(//).reverse.join
      puts "got: #{instr}, replying: #{outstr}"
      [outstr]
    end
  end

  dbus_interface "org.ruby.Ticket30" do
    dbus_method :Sybilla, 'in choices:av, out advice:s' do |choices|
      ["Do #{choices[0]}"]
    end
  end

  dbus_interface "org.ruby.Loop" do
    # starts doing something long, but returns immediately
    # and sends a signal when done
    dbus_method :LongTaskBegin, 'in delay:i' do |delay|
# FIXME did not complain about mismatch between signature and block args
      d "Long task began"
      task = Thread.new do
        d "Long task thread started (#{delay}s)"
        sleep delay
        d "Long task will signal end"
        self.LongTaskEnd
      end
      task.abort_on_exception = true # protect from test case bugs
    end

    dbus_signal :LongTaskEnd
  end
end

bus = DBus::SessionBus.instance
service = bus.request_service("org.ruby.service")
myobj = Test.new("/org/ruby/MyInstance")
service.export(myobj)

puts "listening"
main = DBus::Main.new
main << bus
main.run

