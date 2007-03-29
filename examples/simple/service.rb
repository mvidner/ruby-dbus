#!/usr/bin/ruby

require 'dbus'

bus = DBus.session_bus

service = Service.new("org.ruby.service", bus)

class MyObject < DBus::Object
  dbus_interface "org.ruby.MyInterface"
  dbus_method :MyMethod "in arg0:s" do |arg0|
    puts "You called: MyMethod(#{arg0}), returning \"YAY\""
    return ["YAY"]
  end
end

service.export(MyObject.new("/org/ruby/MyInstance")

loop { bus.process(bus.wait_for_message) }

