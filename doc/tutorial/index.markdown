<style>
code { background-color: #F0E7E7; }
pre code { background-color: #F0DDDD; }
pre {
     font-size: 90%;
     overflow: hidden;
     padding-left: 10pt;
     border: thin solid #F0B4B4;
     background-color: #F0DDDD;
}
</style>

Welcome
=======

This is the Ruby D-Bus tutorial.  It aims to show you the features of Ruby
D-Bus and as you read through the tutorial also how to use them.

&copy; Arnaud Cornet and Paul van Tilburg; this tutorial is part of
free software; you can redistribute it and/or modify it under the
terms of the [GNU Lesser General Public License,
version 2.1](http://www.gnu.org/licenses/lgpl.html) as published by the 
[Free Software Foundation](http://www.fsf.org/).

Introduction
============

This is a tutorial for Ruby D-Bus, a library to access D-Bus facilities of your
system.

What is D-Bus?
--------------

D-Bus is an RPC(Remote Procedure Call) protocol.  A common setup can have
multiple D-Bus daemons running that route procedure calls and signals in
the form of messages.  Each of these daemons supports a bus.  A bus that
is often used by modern desktop environments, and is available per session, is
called the _session bus_.  Another bus that can be available, but in a
system-wide manner, is called the _system bus_.  It is used for example by
the [Hardware Abstraction Layer](http://hal.freedesktop.org/) daemon.  Note
that theoretically the D-Bus RPC protocol can be used without a system or
session bus.  I never came across any actual use of this though.

At the desktop level, D-Bus allows some components to interact.  Typically
if you are writing an application or a personal script that wants to
interact with your web browser, your music player, or that simply wants to
pop-up a desktop notification, D-Bus comes into play.

At the system level, the Hardware Abstraction Layer is a privileged daemon
that notifies other software of hardware activities.  Typically, if you
want to be notified if a CD-ROM has been loaded in, of if you want to
explore hardware, the system daemon comes into play.

The D-Bus RPC system is as we will see _object oriented_.

Buses provide access to _services_ provided in turn by running or ready to
run processes.  Let me introduce some D-Bus terminology before we discuss
the API of Ruby D-Bus.

Client
------

A D-Bus client is a process that connects to a D-Bus. They issue method
calls and register to the bus for signals and events.

Service
-------

A connected client can export some of its objects and let other clients
call some of its methods.  Such clients typically register a special name
like `org.freedesktop.Notifications`, the service name.

There is slightly different type of service.  They are provided by
processes that can be launched by a D-Bus daemon on demand.  Once they are
started by D-Bus they register a service name and behave like another
client.

Note that the buses themselves provide the `org.freedesktop.DBus` service,
and provide some features through it.

Object path
-----------

An object path is the D-Bus way to specify an object _instance_ address.  A
service can provide different object instances to the outside world, so
that external processes can call methods on each of them.  An object path
is an address of an instance in a very similar way that the path is an
address of a file on a file system.  For example: 
`/org/freedesktop/Notification` is an object path of an object provided by
the `org.freedesktop.Notification` service

**Beware**:  service names and object paths can, but do _not_ have to be
related!  You'll probably encounter a lot of cases though, where the
object path is a slashed version of the dotted service name.

Interface
---------

Classically in an object model, classes can implement interfaces. That is,
some method definitions grouped in an interface. This is exactly what a
D-Bus interface is as well. In D-Bus interfaces have names. These names must be
specified on method calls.

The `org.freedesktop.Notification` service provides an object instance
called `/org/freedesktop/Notification`.  This instance object implements an
interface called `org.freedesktop.Notifications`.  It also provides two
special D-Bus specific interfaces:  `org.freedesktop.DBus.Introspect` and
`org.freedesktop.DBus.Properties`. Again, object paths, service names,
and interface names can be related but do not have to be.

Basically the `org.freedesktop.DBus.Introspect` has an `Introspect` method,
that returns XML data describing the `/org/freedesktop/Notification` object
interfaces. This is used heavily internally by Ruby D-Bus.

Method
------

A method is, well, a method in the classical meaning. It's a function that
is called in the context of an object instance. Methods have typed
parameters and return typed return values.

Signal
------

Signals are simplified method calls that do not have a return value. They
do have typed parameters though.

Message
-------

Method calls, method returns, signals, errors: all are encoded as D-Bus
messages sent over a bus. They are made of a packet header with source and
destination address, a type (method call, method reply, signal) and the
body containing the parameters (for signals and method calls) or the return
values (for a method return message).

Signature
---------

Because D-Bus is typed and dynamic, each message comes with a signature that
describes the types of the data that is contained within the message.  The
signature is a string with an extremely basic language that only describes
a data type.  You will need to have some knowledge of what a signature
looks like if you are setting up a service.  If you are just programming a
D-Bus client, you can live without knowing about them.

Client Usage
============

This chapter discusses basic client usage
and has the following topics:

Using the library
-----------------

If you want to use the library, you have to make Ruby load it by issuing:

    require 'dbus'

That's all!  Now we can move on to really using it...

Connecting to a bus
-------------------

On a typical system, two buses are running, the system bus and the session
bus.  The system bus can be accessed by:

    bus = DBus::SystemBus.instance

Probably you already have guessed how to access the session bus. This
can be done by:

    bus = DBus::SessionBus.instance

Performing method calls
-----------------------

Let me continue this example using the session bus.  Let's say that I want
to access an object of some client on the session bus.  This particular
D-Bus client provides a service called `org.gnome.Rhythmbox`.  Let me
access this service:

    rb_service = bus.service("org.gnome.Rhythmbox")

In this example I access the `org.gnome.Rhythmbox` service, which is
provided by the application
[Rhythmbox](http://www.gnome.org/projects/rhythmbox/).
OK, I have a service handle now, and I know that it exports the object
"/org/gnome/Rhythmbox/Player".  I will trivially access this remote object
using:

    rb_player = rb_service.object("/org/gnome/Rhythmbox/Player")

Introspection
-------------

Well, that was easy.  Let's say that I know that this particular object is
introspectable.  In real life most of them are.  The `rb_object` object we
have here is just a handle of a remote object, in general they are called
_proxy objects_, because they are the local handle of a remote object.  It
would be nice to be able to make it have methods, and that its methods send
a D-Bus call to remotely execute the actual method in another process. 
Well, instating these methods for a _introspectable_ object is trivial:

    rb_player.introspect

And there you go.  Note that not all services or objects can be
introspected, therefore you have to do this manually!  Let me remind you
that objects in D-Bus have interfaces and interfaces have methods.  Let's
now access these methods:

    rb_player_iface = rb_player["org.gnome.Rhythmbox.Player"]
    puts rb_player_iface.getPlayingUri

As you can see, when you want to call a method on an instance object, you have
to get the correct interface. It is a bit tedious, so we have the following
shortcut that does the same thing as before:

    rb_player.default_iface = "org.gnome.Rhythmbox.Player"
    puts rb_player.getPlayingUri

The `default_iface=` call specifies the default interface that should be
used when non existing methods are called directly on a proxy object, and
not on one of its interfaces.

Note that the bus itself has a corresponding introspectable object. You can
access it with `bus.proxy` method. For example, you can retrieve an array of
exported service names of a bus like this:

    bus.proxy.ListNames[0]

Properties
----------

Some D-Bus objects provide access to properties. They are accessed by
treating a proxy interface as a hash:

    nm_iface = network_manager_object["org.freedesktop.NetworkManager"]
    enabled = nm_iface["WirelessEnabled"]
    puts "Wireless is " + (enabled ? "enabled":"disabled")
    puts "Toggling wireless"
    nm_iface["WirelessEnabled"] = ! enabled


Calling a method asynchronously
-------------------------------

D-Bus is _asynchronous_.  This means that you do not have to wait for a
reply when you send a message.  When you call a remote method that takes a
lot of time to process remotely, you don't want your application to hang,
right?  Well the asychronousness exists for this reason.  What if you dont'
want to wait for the return value of a method, but still you want to take
some action when you receive it?

There is a classical method to program this event-driven mechanism.  You do
some computation, perform some method call, and at the same time you setup
a callback that will be triggered once you receive a reply.  Then you run a
main loop that is responsible to call the callbacks properly.  Here is how
you do it:

    rb_player.getPlayingUri do |resp|
    	puts "The playing URI is #{resp}"
    end
    puts "See, I'm not waiting!"
    loop = DBus::Main.new
    loop << bus
    loop.run

This code will print the following:

    See, I'm not waiting!
    The playing URI is file:///music/papapingoin.mp3

Waiting for a signal
--------------------

Signals are calls from the remote object to your program.  As a client, you
set yourself up to receive a signal and handle it with a callback.  Then running
the main loop triggers the callback.  You can register a callback handler
as allows:

    rb_player.on_signal("elapsedChanged") do |u|
    	puts u
    end

More about introspection
------------------------

There are various ways to inspect a remote service.  You can simply call
`Introspect()` and read the XML output.  However, in this tutorial I assume
that you want to do it using the Ruby D-Bus API.

Notice that you can introspect a service, and not only objects:

    rb_service = bus.service("org.gnome.Rhythmbox")
    rb_service.introspect
    p rb_service.root

This dumps a tree-like structure that represents multiple object paths.  In
this particular case the output is:

    </: {org => {gnome => {Rhythmbox => {Player => ..fdbe625de {},Shell => ..fdbe6852e {},PlaylistManager => ..fdbe4e340 {}}>

Read this left to right:  the root node is "/", it has one child node "org",
"org" has one child node "gnome", and "gnome" has one child node "Rhythmbox". 
Rhythmbox has Tree child nodes "Player", "Shell" and "PlaylistManager". 
These three last child nodes have a weird digit that means it has an object
instance.  Such object instances are already introspected.

If the prose wasn't clear, maybe the following ASCII art will help you:

    /
    	org
    		gnome
    			Rhythmbox
    				Shell (with object)
    				Player (with object)
    				PlaylistManager (with object)

### Walking the object tree

You can have an object on any node, i.e. it is not limited to leaves.
You can access a specific node like this:

    rb_player = rb_service.root["org"]["gnome"]["Rhythmbox"]["Player"]
    rb_player = rb_service.object("/org/gnome/Rhythmbox/Player")

The difference between the two is that for the first one, `rb_service`
needs to have been introspected.  Also the obtained `rb_player` is already
introspected whereas the second `rb_player` isn't yet.

Errors
------

D-Bus calls can reply with an error instead of a return value. An error is
translated to a Ruby exception.

    begin
        network_manager.sleep
    rescue DBus::Error => e
        puts e unless e.name == "org.freedesktop.NetworkManager.AlreadyAsleepOrAwake"
    end

Creating a Service
==================

This chapter deals with the opposite side of the basic client usage, namely
the creation of a D-Bus service.

Registering a service
---------------------

Now that you know how to perform D-Bus calls, and how to wait for and
handle signals, you might want to learn how to publish some object and
interface to provide them to the D-Bus world.  Here is how you do that.

As you should already know, D-Bus clients that provide some object to be
called remotely are services.  Here is how to allocate a name on a bus:

    bus = DBus.session_bus
    service = bus.request_service("org.ruby.service")

Now this client is know to the outside world as `org.ruby.service`.
Note that this is a request and it _can_ be denied! When it
is denied, an exception (`DBus::NameRequestError`) is thrown.

Exporting an object
-------------------

Now, let's define a class that we want to export:

    class Test < DBus::Object
      # Create an interface.
      dbus_interface "org.ruby.SampleInterface" do
        # Create a hello method in that interface.
        dbus_method :hello, "in name:s, in name2:s" do |name, name2|
          puts "hello(#{name}, #{name2})"
        end
      end
    end

As you can see, we define a `Test` class in which we define a
`org.ruby.SampleInterface` interface.  In this interface, we define a
method.  The given code block is the method's implementation.  This will be
executed when remote programs performs a D-Bus call.  Now the annoying part:
the actual method definition.  As you can guess the call

    dbus_method :hello, "in name:s, in name2:s" do ...

creates a `hello` method that takes two parameters both of type string. 
The _:s_ means "of type string".  Let's have a look at some other common
parameter types:

- *u* means unsigned integer
- *i* means integer
- *y* means byte
- *(ui)* means a structure having a unsigned integer and a signed one.
- *a* means array, so that "ai" means array of integers
    - *as* means array of string
    - *a(is)* means array of structures, each having an integer and a string.

For a full description of the available D-Bus types, please refer to the 
[D-Bus specification](http://dbus.freedesktop.org/doc/dbus-specification.html#message-protocol-signatures).

Now that the class has been defined, we can instantiate an object
and export it as follows:

    exported_obj = Test.new("/org/ruby/MyInstance")
    service.export(exported_obj)

This piece of code above instantiates a `Test` object with a D-Bus object
path.  This object is reachable from the outside world after
`service.export(exported_obj)` is called.

We also need a loop which will read and process the calls coming over the bus:

    loop = DBus::Main.new
    loop << bus
    loop.run

### Using the exported object

Now, let's consider another program that will access our newly created service:

    ruby_service = bus.service("org.ruby.service")
    obj = ruby_service.object("/org/ruby/MyInstance")
    obj.introspect
    obj.default_iface = "org.ruby.SampleInterface"
    obj.hello("giligiligiligili", "haaaaaaa")

As you can see, the object we defined earlier is automatically introspectable.
See also "Basic Client Usage".

Emitting a signal
-----------------

Let's add some example method so you can see how to return a value to the
caller and let's also define another example interface that has a signal.

    class Test2 < DBus::Object
      # Create an interface
      dbus_interface "org.ruby.SampleInterface" do
        # Create a hello method in the interface:
        dbus_method :hello, "in name:s, in name2:s" do |name, name2|
          puts "hello(#{name}, #{name2})"
        end
        # Define a signal in the interface:
        dbus_signal :SomethingJustHappened, "toto:s, tutu:u"
      end

      dbus_interface "org.ruby.AnotherInterface" do
        dbus_method :ThatsALongMethodNameIThink, "in name:s, out ret:s" do |name|
          ["So your name is #{name}"] 
        end
      end
    end

Triggering the signal is a easy as calling a method, but then this time on
a local (exported) object and not on a remote/proxy object:

    exported_obj.SomethingJustHappened("blah", 1)

Note that the `ThatsALongMethodNameIThink` method is returning a single
value to the caller.  Notice that you always have to return an array.  If
you want to return multiple values, just have an array with multiple
values.

Replying with an error
----------------------

To reply to a dbus_method with a D-Bus error, raise a `DBus::Error`,
as constructed by the `error` convenience function:

    raise DBus.error("org.example.Error.SeatOccupied"), "Seat #{seat} is occupied"

If the error name is not specified, the generic
`org.freedesktop.DBus.Error.Failed` is used.

    raise DBus.error, "Seat #{seat} is occupied"
    raise DBus.error
