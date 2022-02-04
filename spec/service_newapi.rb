#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require_relative "spec_helper"
SimpleCov.command_name "Service Tests" if Object.const_defined? "SimpleCov"
# find the library without external help
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require "dbus"

PROPERTY_INTERFACE = "org.freedesktop.DBus.Properties".freeze

class Test < DBus::Object
  INTERFACE = "org.ruby.SampleInterface".freeze
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

    dbus_attr_accessor :read_or_write_me, "s"
    dbus_attr_reader :read_me, "s"

    def write_me=(value)
      @read_me = value
    end
    dbus_writer :write_me, "s"
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

  dbus_interface "org.ruby.Duplicates" do
    dbus_method :the_answer, "out answer:i" do
      [0]
    end
    dbus_method :interfaces, "out answer:i" do
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

  # ==================================================
  # INTERNAL NOTES
  # TODO: again ensure that we are inside a dbus_interface block

  # low level for doing weird things? probably unnecessary
  # Declaring a property that is neiter readable nor writable
  # raises an exception.
  #
  # @param ruby_name [Symbol]
  # @param write [Boolean]
  # @param read [Boolean]
  # @param dbus_name [String] if not given it is made
  #   by CamelCasing the ruby_name. foo_bar becomes FooBar
  #   to convert the Ruby convention to the DBus convention
  # @param emits_changed_signal [true,false,:invalidates,:const]
  #   FIXME: ignored for now, true assumed. (also applies to interface)
  # dbus_property(ruby_name, type, read:, write:, dbus_name:)

  # MAKE INTROSPECTION WORK!

  # =========================================
  # DOC

  # @example

  # dbus_reader/writer/accessor does notimply
  # attr_reader/attr_writer/attr_accessor

  # The names are chosen to mimic the Ruby declarations `attr_reader`, `attr_writer`, attr_accessor`.

  # DBus property Foo does not care about the Ruby instance variable @foo.
  # It always uses the methods #foo or #foo=.
  # dbus_writer :foo actually wraps #foo= so that it can send
  # a PropertiesChanged signal. The original version is #_original_foo=.
  # Therefore the correct declaration order is
  #
  # def foo=(val); ...; end
  # dbus_writer :foo, Type::STRING

  # https://ruby-doc.org/stdlib-2.5.0/libdoc/observer/rdoc/Observable.html
  # does not seem useful

  # ruby @foo_bar, dbus FooBar
  # type: eg Type::STRING (looks up DBus::Type::STRING)
  # next: make aliases directly in DBus (maybe DBus::Object)
  dbus_reader :read_it, DBus::Type::STRING

  # omit type to mean variant?
  dbus_writer :write_it, DBus::Type::VARIANT

  # ARRAY does not work this way. DBus.type("av")
  # dbus_accessor :baz, DBus::Type::ARRAY(DBus::Type::VARIANT)
  dbus_accessor :baz, DBus::Type::ARRAY

  # what about multiple interfaces?
  # spec says that empty interface is ok as long as name unique
  # that should be OK with ruby_name dbus_name params :)

  # On bus read (Get)
  # call #a_prop
  # translate exception to error
  # type check? bus probably checks for us. test case for that

  # On bus read all (GetAll)
  # call #a_prop for all, but rescue access control errors and omit those props
  # translate exception to error

  # On bus write (Set)
  # call #_original_a_prop=
  #   (so that we don't emit a PC signal)
  # translate exception to error

  # Local read
  # No special code needed. User defines #a_prop

  # Local write
  # if not bus-readable (access=write) then just do (2) and return
  # (but still create #_original_a_prop to make Set simple)
  #
  # 1. early type check: don't update @a_prop if the clients cannot read it
  #       (Get will type check again, but early is better)
  # 2. call #_original_a_prop=
  # 3. tell dbus about AProp change
  def a_prop=(value)
    # dissociate the object API from the DBus helpers. initially helper=self
    helper.type_check(value, type)
    # call old method
    @a_prop = value
    #
    # PropertiesChanged(STRING interface_name,
    #                   DICT<STRING,VARIANT> changed_properties,
    #                   ARRAY<STRING> invalidated_properties)
    helper.properties_changed(name, value)
    #
  end

  # Properties:
  # ReadMe:string, returns "READ ME" at first, then what WriteMe received
  # WriteMe:string
  # ReadOrWriteMe:string, returns "READ OR WRITE ME" at first
  dbus_interface PROPERTY_INTERFACE do
    dbus_method :Get, "in interface:s, in propname:s, out value:v" do |interface, propname|
      unless interface == INTERFACE
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"),
              "Interface '#{interface}' not found on object '#{@path}'"
      end

      case propname
      when "ReadMe"
        [@read_me]
      when "ReadOrWriteMe"
        [@read_or_write_me]
      when "WriteMe"
        raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"),
              "Property '#{interface}.#{propname}' (on object '#{@path}') is not readable"
      else
        # what should happen for unknown properties
        # plasma: InvalidArgs (propname), UnknownInterface (interface)
        raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"),
              "Property '#{interface}.#{propname}' not found on object '#{@path}'"
      end
    end

    dbus_method :Set, "in interface:s, in propname:s, in  value:v" do |interface, propname, value|
      unless interface == INTERFACE
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"),
              "Interface '#{interface}' not found on object '#{@path}'"
      end

      case propname
      when "ReadMe"
        raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"),
              "Property '#{interface}.#{propname}' (on object '#{@path}') is not writable"
      when "ReadOrWriteMe"
        @read_or_write_me = value
        self.PropertiesChanged(interface, { propname => value }, [])
      when "WriteMe"
        @read_me = value
        self.PropertiesChanged(interface, { "ReadMe" => value }, [])
      else
        raise DBus.error("org.freedesktop.DBus.Error.InvalidArgs"),
              "Property '#{interface}.#{propname}' not found on object '#{@path}'"
      end
    end

    dbus_method :GetAll, "in interface:s, out value:a{sv}" do |interface|
      unless interface == INTERFACE
        raise DBus.error("org.freedesktop.DBus.Error.UnknownInterface"),
              "Interface '#{interface}' not found on object '#{@path}'"
      end

      [
        {
          "ReadMe" => @read_me,
          "ReadOrWriteMe" => @read_or_write_me
        }
      ]
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
    DBus.logger.debug "RRRING #{new_unique_name}"
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
