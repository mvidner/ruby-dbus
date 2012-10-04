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

The following code is assumed as a prolog to all following ones

{include:file:doc/ex-setup.rb}    

#### Calling Methods

1. {DBus.session_bus Connect to the session bus};
   {DBus::Connection#[] get the screensaver service}
   {DBus::Service#object and its screensaver object}.
2. Perform {DBus::ProxyObject#introspect explicit introspection}
   to define the interfaces and methods
   on the {DBus::ProxyObject object proxy}
([I#28](https://github.com/mvidner/ruby-dbus/issues/28)).
3. Get the screensaver {DBus::ProxyObject#[] interface}
([I#29](https://github.com/mvidner/ruby-dbus/issues/29)).
4. Call one of its methods in a loop, solving [xkcd#196](http://xkcd.com/196).

{include:file:doc/ex-calling-methods.body.rb}

##### Retrieving Return Values

A method proxy always returns an array of values. This is to
accomodate the rare cases of a DBus method specifying more than one
*out* parameter. For nearly all methods you should use `Method[0]` or
`Method.first`
([I#30](https://github.com/mvidner/ruby-dbus/issues/30)).

    
    # wrong
    if upower_i.SuspendAllowed    # [false] is true!
      upower_i.Suspend
    end

    # right
    if upower_i.SuspendAllowed[0]
      upower_i.Suspend
    end

#### Accessing Properties

To access properties, think of the {DBus::ProxyObjectInterface interface} as a
{DBus::ProxyObjectInterface#[] hash} keyed by strings,
or use {DBus::ProxyObjectInterface#all_properties} to get
an actual Hash of them.

{include:file:doc/ex-properties.body.rb}

(TODO a writable property example)

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
{DBus::ProxyObjectInterface#on\_signal}(bus, name, &block) or
{DBus::ProxyObject#on_signal}(name, &block), for the default interface.
([I#31](https://github.com/mvidner/ruby-dbus/issues/31))

{include:file:doc/ex-signal.body.rb}

### Intermediate Concepts
#### Names
#### Types
#### Errors
#### Interfaces
#### Thread Safety
Not there. An [incomplete attempt] was made.
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
### Advanced
#### Inheritance
#### Names

Specification Conformance
-------------------------

This section lists the known deviations from version 0.19 of
[the specification][spec].

[spec]: http://dbus.freedesktop.org/doc/dbus-specification.html

1. Properties support is basic.
