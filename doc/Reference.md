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

1. Connect to the session bus; get the screensaver service and its
screensaver object.
2. Perform explicit introspection to define the interfaces and methods
on the {DBus::ProxyObject object proxy}
({https://github.com/mvidner/ruby-dbus/issues/28 I#28}).
3. Get the screensaver interface
({https://github.com/mvidner/ruby-dbus/issues/29 I#29}).
4. Call one of its methods in a loop, solving [xkcd#196](http://xkcd.com/196).

{include:file:doc/ex-calling-methods.body.rb}

##### Retrieving Return Values

A method proxy always returns an array of values. This is to
accomodate the rare cases of a DBus method specifying more than one
*out* parameter. For nearly all methods you should use `Method[0]` or
`Method.first`
({https://github.com/mvidner/ruby-dbus/issues/30 I#30}).

    
    # wrong
    if upower_i.SuspendAllowed    # [false] is true!
      upower_i.Suspend
    end

    # right
    if upower_i.SuspendAllowed[0]
      upower_i.Suspend
    end

#### Accessing Properties

{include:file:doc/ex-properties.body.rb}

#### Receiving Signals


#### Asynchronous Operation
##### Main Loop

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
