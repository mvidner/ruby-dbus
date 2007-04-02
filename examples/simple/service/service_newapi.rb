#!/usr/bin/ruby

require 'dbus'
require 'thread'
Thread.abort_on_exception = true

class Test < DBus::Object
  # Create an interface aggregating all upcoming dbus_method defines.
  dbus_interface "org.ruby.SampleInterface" do
    dbus_method :hello, "in name:s, in name2:s" do |name, name2|
      puts "hello(#{name}, #{name2})"
    end

    dbus_signal :SomethingJustHappened, "toto:s, tutu:u"
  end

  dbus_interface "org.ruby.AnotherInterface" do
    dbus_method :ThatsALongMethodNameIThink do
      puts "ThatsALongMethodNameIThink"
    end
  end
end

bus = DBus.session_bus
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
loop { bus.process(bus.wait_for_message) }

