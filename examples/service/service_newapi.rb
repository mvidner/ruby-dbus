#!/usr/bin/env ruby

require 'dbus'
require 'thread'
Thread.abort_on_exception = true

class Test < DBus::Object
  # replace all nil values by empty string. Useful mainly for variants.
  self.default_for_nil = ""
  # Create an interface aggregating all upcoming dbus_method defines.
  dbus_interface "org.ruby.SampleInterface" do
    dbus_method :hello, "in name:s, in name2:s" do |name, name2|
      puts "hello(#{name}, #{name2})"
    end

    dbus_method :test_variant, "in stuff:v" do |variant|
      p variant
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
end

bus = DBus::SessionBus.instance
service = bus.request_service("org.ruby.service")
myobj = Test.new("/org/ruby/MyInstance")
service.export(myobj)

Thread.new do
  i = 0
  loop do 
    # Signal emission
    myobj.SomethingJustHappened("hey", i += 1)
    sleep(0.5)
  end
end

puts "listening"
main = DBus::Main.new
main << bus
main.run

