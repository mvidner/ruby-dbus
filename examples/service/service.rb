#!/usr/bin/ruby

require 'dbus'
Thread.abort_on_exception = true

bus = DBus.session_bus

r = bus.proxy.RequestName("org.ruby.service",
                        DBus::Connection::NAME_FLAG_REPLACE_EXISTING)
if r[0] != DBus::Connection::REQUEST_NAME_REPLY_PRIMARY_OWNER
  puts "ouch"
  exit
end

intf = DBus::Interface.new("org.ruby.MyInterface")
intf.define_method(:MyMethod, "in mystring:s, out ret1:s")

class MyObject < DBus::Object
  def MyMethod(mystring)
    puts "You called: MyMethod, returning YAY"
    return ["YAY"]
  end
end

obj = MyObject.new("/org/ruby/MyInstance")
obj.implements(intf)
bus.export_object(obj)

loop { bus.process(bus.wait_for_message) }

