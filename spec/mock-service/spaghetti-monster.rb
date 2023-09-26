#!/usr/bin/env ruby
# frozen_string_literal: true

# This file was formerly named spec/service_newapi.rb, after the example
# which it mutated from.
# Spaghetti monster is a better name,
# reflecting on its evolution and current nature :'-)

require_relative "../coverage_helper"
SimpleCov.command_name "Service Tests (#{Process.pid})" if Object.const_defined? "SimpleCov"

# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../lib", __dir__)

require "dbus"

SERVICE_NAME = "org.ruby.service"

class TestChild < DBus::Object
  def initialize(opath)
    @name = opath.split("/").last.capitalize
    super
  end

  dbus_interface "org.ruby.TestChild" do
    dbus_reader_attr_accessor :name, "s"
  end
end

class Test < DBus::Object
  Point2D = Struct.new(:x, :y)

  attr_writer :main_loop

  include DBus::ObjectManager

  INTERFACE = "org.ruby.SampleInterface"
  def initialize(path)
    super path
    @read_me = "READ ME"
    @read_or_write_me = "READ OR WRITE ME"
    @my_struct = ["three", "strings", "in a struct"].freeze
    @my_array = [42, 43]
    @my_dict = {
      "one" => 1,
      "two" => "dva",
      "three" => [3, 3, 3]
    }
    @my_variant = @my_array.dup
    # 201 is a RET instruction for ZX Spectrum which has turned 40 recently
    @my_byte = 201
    @main_loop = nil
  end

  # Create an interface aggregating all upcoming dbus_method defines.
  dbus_interface INTERFACE do
    dbus_method :quit, "" do
      @main_loop&.quit
    end

    dbus_method :hello, "in name:s, in name2:s" do |name, name2|
      puts "hello(#{name}, #{name2})"
    end

    dbus_method :test_variant, "in stuff:v" do |variant|
      DBus.logger.debug variant.inspect
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

    dbus_method :mirror_byte_array, "in bytes:ay, out mirrored:ay" do |bytes|
      [bytes]
    end

    dbus_method :Coordinates, "out coords:(dd)" do
      coords = [3.0, 4.0].freeze
      [coords]
    end

    dbus_method :Coordinates2, "out coords:(dd)" do
      coords = Point2D.new(5.0, 12.0)
      [coords]
    end

    # Two OUT arguments
    dbus_method :EvenOdd, "in numbers:ai, out even:ai, out odd:ai" do |numbers|
      even, odd = numbers.partition(&:even?)
      [even, odd]
    end

    # Properties:
    # ReadMe:string, returns "READ ME" at first, then what WriteMe received
    # WriteMe:string
    # ReadOrWriteMe:string, returns "READ OR WRITE ME" at first
    dbus_attr_accessor :read_or_write_me, "s"
    dbus_attr_reader :read_me, "s"

    def write_me=(value)
      @read_me = value
    end
    dbus_writer :write_me, "s"

    dbus_attr_writer :password, "s"

    # a property that raises when client tries to read it
    def explosive
      raise "Something failed"
    end
    dbus_reader :explosive, "s"

    dbus_attr_accessor :my_struct, "(sss)"
    dbus_attr_accessor :my_array, "aq"
    dbus_attr_accessor :my_dict, "a{sv}"
    dbus_attr_accessor :my_variant, "v"

    dbus_attr_accessor :my_byte, "y"

    # to test dbus_properties_changed
    dbus_method :SetTwoProperties, "in read_me:s, in byte:y" do |read_me, byte|
      @read_me = read_me
      @my_byte = byte
      dbus_properties_changed(INTERFACE,
                              { "ReadMe" => read_me, "MyByte" => byte },
                              [])
    end
  end

  # closing and reopening the same interface
  dbus_interface INTERFACE do
    dbus_method :multibyte_string, "out string:s" do
      "あいうえお"
    end

    dbus_method :i16_plus, "in a:n, in b:n, out result:n" do |a, b|
      a + b
    end

    dbus_signal :SomethingJustHappened, "toto:s, tutu:u"
  end

  dbus_interface "org.ruby.AnotherInterface" do
    dbus_method :ThatsALongMethodNameIThink do
      puts "ThatsALongMethodNameIThink"
    end
    dbus_method :Reverse, "in instr:s, out outstr:s" do |instr|
      outstr = instr.split(//).reverse.join
      [outstr]
    end
  end

  dbus_interface "org.ruby.Ticket30" do
    dbus_method :Sybilla, "in choices:av, out advice:s" do |choices|
      ["Do #{choices[0]}"]
    end
  end

  dbus_interface "org.ruby.TestParent" do
    dbus_method :New, "in name:s, out opath:o" do |name|
      child = TestChild.new("#{path}/#{name}")
      object_server.export(child)
      [child.path]
    end

    dbus_method :Delete, "in opath:o" do |opath|
      raise ArgumentError unless opath.start_with?(path)

      object_server.unexport(opath)
    end
  end

  dbus_interface "org.ruby.Duplicates" do
    dbus_method :the_answer, "out answer:i" do
      [0]
    end

    dbus_method :interfaces, "out answer:i" do
      # 'Shadowed' from the Ruby side, meaning ProxyObject#interfaces
      # will return the list of interfaces rather than calling this method.
      # Calling it with busctl will work just fine.
      raise "This DBus method is currently shadowed by ProxyObject#interfaces"
    end
  end

  dbus_interface "org.ruby.Loop" do
    # starts doing something long, but returns immediately
    # and sends a signal when done
    dbus_method :LongTaskBegin, "in delay:i" do |delay|
      # FIXME: did not complain about mismatch between signature and block args
      self.LongTaskStart
      DBus.logger.debug "Long task began"
      task = Thread.new do
        DBus.logger.debug "Long task thread started (#{delay}s)"
        sleep delay
        DBus.logger.debug "Long task will signal end"
        self.LongTaskEnd
      end
      task.abort_on_exception = true # protect from test case bugs
    end

    dbus_signal :LongTaskStart
    dbus_signal :LongTaskEnd
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
service = bus.object_server
myobj = Test.new("/org/ruby/MyInstance")
service.export(myobj)
derived = Derived.new "/org/ruby/MyDerivedInstance"
service.export derived
test2 = Test2.new "/org/ruby/MyInstance2"
service.export test2
bus.request_name(SERVICE_NAME)

# introspect every other connection, Ticket #34
#  (except the one that activates us - it has already emitted
#  NOC by the time we run this. Therefore the test for #34 will not work
#  by running t2.rb alone, one has to run t1 before it; 'rake' does it)
mr = DBus::MatchRule.new.from_s "type='signal',interface='org.freedesktop.DBus',member='NameOwnerChanged'"
bus.add_match(mr) do |msg|
  new_unique_name = msg.params[2]
  unless new_unique_name.empty?
    DBus.logger.debug "RRRING #{new_unique_name}"
    bus.introspect_data(new_unique_name, "/") do
      # ignore the result
    end
  end
end

DBus.logger.info "Service #{SERVICE_NAME} listening, with ruby-#{RUBY_VERSION}"
main = DBus::Main.new
main << bus
myobj.main_loop = main
begin
  main.run
rescue SystemCallError, SignalException => e
  DBus.logger.info "Service #{SERVICE_NAME} got #{e.inspect}, exiting"
  # the test driver will kill the bus, that's OK
end
