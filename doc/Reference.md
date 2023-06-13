Ruby D-Bus Reference
====================

This is a reference-style documentation. It's not [a tutorial for
beginners](http://dbus.freedesktop.org/doc/dbus-tutorial.html), the
reader should have knowledge of basic DBus concepts.

Client Side
-----------

This section should be enough if you only want to consume DBus APIs.

### Basic Concepts

#### Setting Up

Note that although the gem is named "ruby-dbus", the required name
is simply "dbus"

    #! /usr/bin/env ruby
    require "dbus"

#### Calling Methods

1. {DBus.session_bus Connect to the session bus};
2. {DBus::BusConnection#[] get the screensaver service}
3. {DBus::ProxyService#[] and its screensaver object}.
4. Call one of its methods in a loop, solving [xkcd#196](http://xkcd.com/196).

&nbsp;

    mybus = DBus.session_bus
    service = mybus["org.freedesktop.ScreenSaver"]
    object = service["/ScreenSaver"]
    loop do
      object.SimulateUserActivity
      sleep 5 * 60
    end

##### Retrieving Return Values

A method proxy simply returns a value.
In this example SuspendAllowed returns a boolean:

    mybus = DBus.session_bus
    pm_s = mybus["org.freedesktop.PowerManagement"]
    pm_o = pm_s["/org/freedesktop/PowerManagement"]
    pm_i = pm_o["org.freedesktop.PowerManagement"]

    if pm_i.CanSuspend
      pm_i.Suspend
    end

###### Multiple Return Values

In former versions of this library,
a method proxy always returned an array of values. This was to
accomodate the rare cases of a DBus method specifying more than one
*out* parameter. For compatibility, the behavior is preserved if you
construct a {DBus::ProxyObject} with {DBus::ApiOptions::A0},
which is what {DBus::ProxyService#object} does.

For nearly all methods you used `Method[0]` or
`Method.first`
([I#30](https://github.com/mvidner/ruby-dbus/issues/30)).

    mybus = DBus.session_bus
    pm_s = mybus["org.freedesktop.PowerManagement"]
    # use legacy compatibility API
    pm_o = pm_s.object["/org/freedesktop/PowerManagement"]
    pm_i = pm_o["org.freedesktop.PowerManagement"]

    # wrong
    # if pm_i.CanSuspend
    #   pm_i.Suspend                # [false] is true!
    # end

    # right
    if pm_i.CanSuspend[0]
      pm_i.Suspend
    end

#### Accessing Properties

To access properties, think of the {DBus::ProxyObjectInterface interface} as a
{DBus::ProxyObjectInterface#[] hash} keyed by strings,
or use {DBus::ProxyObjectInterface#all_properties} to get
an actual Hash of them.

    sysbus = DBus.system_bus
    upower_s = sysbus["org.freedesktop.UPower"]
    upower_o = upower_s["/org/freedesktop/UPower"]
    upower_i = upower_o["org.freedesktop.UPower"]

    on_battery = upower_i["OnBattery"]

    puts "Is the computer on battery now? #{on_battery}"

(TODO a writable property example)

Note that unlike for methods where the interface is inferred if unambiguous,
for properties the interface must be explicitly chosen.
That is because {DBus::ProxyObject} uses the {DBus::ProxyObject Hash#[]} API
to provide the {DBus::ProxyObjectInterface interfaces}, not the properties.

#### Asynchronous Operation

If a method call has a block attached, it is asynchronous and the block
is invoked on receiving a method_return message or an error message

##### Main Loop

For asynchronous operation an event loop is necessary. Use {DBus::Main}:

    # [set up signal handlers...]
    main = DBus::Main.new
    main << mybus
    main.run

Alternately, run the GLib main loop and add your DBus connections to it via
{DBus::Connection#glibize}.

#### Receiving Signals

To receive signals for a specific object and interface, use
{DBus::ProxyObjectInterface#on\_signal}(name, &block) or
{DBus::ProxyObject#on_signal}(name, &block), for the default interface.

    sysbus = DBus.system_bus
    login_s = sysbus["org.freedesktop.login1"] # part of systemd
    login_o = login_s.object "/org/freedesktop/login1"
    login_o.default_iface = "org.freedesktop.login1.Manager"

    main = DBus::Main.new
    main << sysbus

    # to trigger this signal, login on the Linux console
    login_o.on_signal("SessionNew") do |name, opath|
      puts "New session: #{name}"

      session_o = login_s.object(opath)
      session_i = session_o["org.freedesktop.login1.Session"]
      uid, _user_opath = session_i["User"]
      puts "Its UID: #{uid}"
      main.quit
    end

    main.run

### Intermediate Concepts
#### Names
#### Types and Values, D-Bus -> Ruby

D-Bus booleans, numbers, strings, arrays and dictionaries become their straightforward Ruby counterparts.

Structs become frozen arrays.

Object paths become strings.

Variants are simply unpacked to become their contained type.
(ISSUE: prevents proper round-tripping!)

#### Types and Values, Ruby -> D-Bus

D-Bus has stricter typing than Ruby, so the library must decide
which D-Bus type to choose. Most of the time the choice is dictated
by the D-Bus signature.

For exact representation of D-Bus data types, use subclasses
of {DBus::Data::Base}, such as {DBus::Data::Int16} or {DBus::Data::UInt64}.

##### Variants

If the signature expects a Variant
(which is the case for all Properties!) then an explicit mechanism is needed.

1. Any {DBus::Data::Base}.

2. A {DBus::Data::Variant} made by {DBus.variant}(signature, value).
   (Formerly this produced the type+value pair below, now it is just an alias
   to the Variant constructor.)

3. A pair [{DBus::Type}, value] specifies to marshall *value* as
   that specified type.
   The pair can be produced by {DBus.variant}(signature, value) which
   gives the  same result as [{DBus.type}(signature), value].

   ISSUE: using something else than cryptic signatures is even more painful
   than remembering the signatures!

   `foo_i["Bar"] = DBus.variant("au", [0, 1, 1, 2, 3, 5, 8])`

4. Other values are tried to fit one of these:
   Boolean, Double, Array of Variants, Hash of String keyed Variants,
   String, Int32, Int64.

5. **Deprecated:** A pair [String, value], where String is a valid
   signature of a single complete type, marshalls value as that
   type. This will hit you when you rely on method (4) but happen to have
   a particular string value in an array.

##### Structs

If a **STRUCT** `(...)` is expected you may pass

- an [Array](https://ruby-doc.org/core/Array.html) (frozen is fine)
- a [Struct](https://ruby-doc.org/core/Struct.html)

##### Byte Arrays

If a byte array (`ay`) is expected you can pass a String too.
The bytes sent are according to the string's
[encoding](http://ruby-doc.org/core/Encoding.html).

##### nil

`nil` is not allowed by D-Bus and attempting to send it raises an exception
(but see [I#16](https://github.com/mvidner/ruby-dbus/issues/16)).


#### Errors

D-Bus calls can reply with an error instead of a return value. An error is
translated to a Ruby exception, an instance of {DBus::Error}.

    nm_o = DBus.system_bus["org.freedesktop.NetworkManager"]["/org/freedesktop/NetworkManager"]
    nm = nm_o["org.freedesktop.NetworkManager"]
    begin
      nm.Sleep(false)
    rescue DBus::Error => e
      puts e unless e.name == "org.freedesktop.NetworkManager.AlreadyAsleepOrAwake"
    end

#### Interfaces

Methods, properties and signals of a D-Bus object always belong to one of its interfaces.

Methods can be called without specifying their interface, as long as there is no ambiguity.
There are two ways to resolve ambiguities:

1. assign an interface name to {DBus::ProxyObject#default_iface}.

2. get a specific {DBus::ProxyObjectInterface interface} of the object,
with {DBus::ProxyObject#[]} and call methods from there.

Signals and properties only work with a specific interface.

#### Thread Safety
Not there. An [incomplete attempt](https://github.com/mvidner/ruby-dbus/tree/multithreading) was made.
### Advanced Concepts
#### Bus Addresses
#### Without Introspection
#### Name Overloading

Service Side
------------

When you want to provide a DBus API.

(check that client and service side have their counterparts)

### Basic

#### Exporting a Method

##### Interfaces

##### Methods

##### Bus Names

##### Errors

#### Exporting Properties

Similar to plain Ruby attributes, declared with

- {https://docs.ruby-lang.org/en/3.1/Module.html#method-i-attr_accessor attr_accessor}
- {https://docs.ruby-lang.org/en/3.1/Module.html#method-i-attr_reader attr_reader}
- {https://docs.ruby-lang.org/en/3.1/Module.html#method-i-attr_writer attr_writer}

These methods declare the attributes and export them as properties:

- {DBus::Object.dbus_attr_accessor}
- {DBus::Object.dbus_attr_reader}
- {DBus::Object.dbus_attr_writer}

For making properties out of Ruby methods (which are not attributes), use:

- {DBus::Object.dbus_accessor}
- {DBus::Object.dbus_reader}
- {DBus::Object.dbus_writer}

Note that the properties are declared in the Ruby naming convention with
`snake_case` and D-Bus sees them `CamelCased`. Use the `dbus_name` argument
for overriding this.

&nbsp;

    class Note < DBus::Object
      dbus_interface "net.vidner.Example.Properties" do
        # A read-write property "Title",
        # with `title` and `title=` accessing @title.
        dbus_attr_accessor :title, DBus::Type::STRING

        # A read-only property "Author"
        # (type specified via DBus signature)
        # with `author` reading `@author`
        dbus_attr_reader :author, "s"

        # A read-only property `Clock`
        def clock
          Time.now.to_s
        end
        dbus_reader :clock, "s"

        # Name mapping: `CreationTime`
        def creation_time
          "1993-01-01 00:00:00 +0100"
        end
        dbus_reader :creation_time, "s"

        dbus_attr_accessor :book_volume, DBus::Type::VARIANT, dbus_name: "Volume"
      end

      dbus_interface "net.vidner.Example.Audio" do
        dbus_attr_accessor :speaker_volume, DBus::Type::BYTE, dbus_name: "Volume"
      end

      # Must assign values because `nil` would crash our connection
      def initialize(opath)
        super
        @title = "Ahem"
        @author = "Martin"
        @book_volume = 1
        @speaker_volume = 11
      end
    end

    obj = Note.new("/net/vidner/Example/Properties")

    bus = DBus::SessionBus.instance
    bus.object_server.export(obj)
    bus.request_name("net.vidner.Example")

    main = DBus::Main.new
    main << bus
    main.run

### Advanced

#### Inheritance

#### Names

Specification Conformance
-------------------------

This section lists the known deviations from version 0.19 of
[the specification][spec].

[spec]: http://dbus.freedesktop.org/doc/dbus-specification.html

1. Properties support is basic.
