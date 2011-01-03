#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# find the library without external help
$:.unshift File.expand_path("../../lib", __FILE__)

require 'dbus'

def d(msg)
  puts "#{$$} #{msg}" if $DEBUG
end

PROPERTY_INTERFACE = "org.freedesktop.DBus.Properties"

class Test < DBus::Object
  INTERFACE = "org.ruby.SampleInterface"
  def initialize(path)
    super path
    @read_me = "READ ME"
    @read_or_write_me = "READ OR WRITE ME"
  end

  # Create an interface aggregating all upcoming dbus_method defines.
  dbus_interface INTERFACE do
    dbus_method :hello, "in name:s, in name2:s" do |name, name2|
      puts "hello(#{name}, #{name2})"
    end

    dbus_method :test_variant, "in stuff:v" do |variant|
      p variant
    end

    dbus_method :bounce_variant, "in stuff:v, out chaff:v" do |variant|
      [variant]
    end

    dbus_method :variant_size, "in stuff:v, out size:u" do |variant|
      [variant.size]
    end

    dbus_method :the_answer, "out answer:i" do
      42
    end

    dbus_method :will_raise, "" do
      raise "Handle this"
    end

    dbus_method :will_raise_error_failed, "" do
      raise DBus.error, "failed as designed"
    end

    dbus_method :will_raise_name_error, "" do
      "foo".frobnicate
    end

    dbus_method :Error, "in name:s, in description:s" do |name, description|
      raise DBus.error(name), description
    end
  end

  # closing and reopening the same interface
  dbus_interface INTERFACE do
    dbus_method :multibyte_string, "out string:s" do
      "あいうえお"
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

  # Properties:
  # ReadMe:string, returns "READ ME" at first, then what WriteMe received
  # WriteMe:string
  # ReadOrWriteMe:string, returns "READ OR WRITE ME" at first
  dbus_interface PROPERTY_INTERFACE do
    dbus_method :Get, "in interface:s, in propname:s, out value:v" do |interface, propname|
      if interface == INTERFACE
        if propname == "ReadMe"
          [@read_me]
        elsif propname == "ReadOrWriteMe"
          [@read_or_write_me]
        elsif propname == "WriteMe"
          raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"), "Property '#{interface}.#{propname}' (on object '#{@path}') is not readable"
        else
          raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"), "Property '#{interface}.#{propname}' not found on object '#{@path}'"
        end
      else
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"), "Interface '#{interface}' not found on object '#{@path}'"
      end
# what should happen for unknown properties
# plasma: InvalidArgs (propname), UnknownInterface (interface)
    end

    dbus_method :Set, "in interface:s, in propname:s, in  value:v" do |interface, propname, value|
      if interface == INTERFACE
        if propname == "ReadMe"
          raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"), "Property '#{interface}.#{propname}' (on object '#{@path}') is not writable"
        elsif propname == "ReadOrWriteMe"
          @read_or_write_me = value
          self.PropertiesChanged(interface, {propname => value}, [])
        elsif propname == "WriteMe"
          @read_me = value
          self.PropertiesChanged(interface, {"ReadMe" => value}, [])
        else
          raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"), "Property '#{interface}.#{propname}' not found on object '#{@path}'"
        end
      else
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"), "Interface '#{interface}' not found on object '#{@path}'"
      end
    end

    dbus_method :GetAll, "in interface:s, out value:a{sv}" do |interface|
      if interface == INTERFACE
        [ {
            "ReadMe" => @read_me,
            "ReadOrWriteMe" =>@read_or_write_me,
          } ]
      else
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"), "Interface '#{interface}' not found on object '#{@path}'"
      end
    end

    dbus_signal :PropertiesChanged, "interface:s, changed_properties:a{sv}, invalidated_properties:as"
  end
end

class Derived < Test
end

class Test2 < DBus::Object
  dbus_interface "org.ruby.Test2" do
    dbus_method :hi, "in name:s, out greeting:s" do |name|
      "Hi, #{name}!"
    end
  end
end

bus = DBus::SessionBus.instance
service = bus.request_service("org.ruby.service")
myobj = Test.new("/org/ruby/MyInstance")
service.export(myobj)
derived = Derived.new "/org/ruby/MyDerivedInstance"
service.export derived
test2 = Test2.new "/org/ruby/MyInstance2"
service.export test2 

# introspect every other connection, Ticket #34
#  (except the one that activates us - it has already emitted
#  NOC by the time we run this. Therefore the test for #34 will not work
#  by running t2.rb alone, one has to run t1 before it; 'rake' does it)
mr = DBus::MatchRule.new.from_s "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
bus.add_match(mr) do |msg|
  new_unique_name = msg.params[2]
  unless new_unique_name.empty?
    d "RRRING #{new_unique_name}"
    bus.introspect_data(new_unique_name, "/") do
      # ignore the result
    end
  end
end

puts "listening, with ruby-#{RUBY_VERSION}"
main = DBus::Main.new
main << bus
begin
  main.run
rescue SystemCallError
  # the test driver will kill the bus, that's OK
end

