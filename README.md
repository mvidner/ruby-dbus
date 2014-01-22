# Ruby D-Bus README

[D-Bus](http://dbus.freedesktop.org) is an interprocess communication
mechanism for Linux.
Ruby D-Bus is a pure Ruby library for writing clients and services for D-Bus.

## Example

Check whether the system is on battery power
via [UPower](http://upower.freedesktop.org/docs/UPower.html#UPower:OnBattery)

```ruby
require "dbus"
sysbus = DBus.system_bus
upower_service   = sysbus["org.freedesktop.UPower"]
upower_object    = upower_service.object "/org/freedesktop/UPower"
upower_object.introspect
upower_interface = upower_object["org.freedesktop.UPower"]
on_battery       = upower_interface["OnBattery"]
if on_battery
  puts "The computer IS on battery power."
else
  puts "The computer IS NOT on battery power."
end
```

## Requirements

- Ruby 1.9.3 or 2.0

[![Build Status](https://travis-ci.org/mvidner/ruby-dbus.png)](https://travis-ci.org/mvidner/ruby-dbus)

## Installation

- `gem install ruby-dbus`

## Features

Ruby D-Bus currently supports the following features:

 * Connecting to local buses.
 * Accessing remote services, objects and interfaces.
 * Invoking methods on remote objects synchronously and asynchronously.
 * Catch signals on remote objects and handle them via callbacks.
 * Remote object introspection.
 * Walking object trees.
 * Creating services and registering them on the bus.
 * Exporting objects with interfaces on a bus for remote use.
 * Rubyish D-Bus object and interface syntax support that automatically
   allows for introspection.
 * Emitting signals on exported objects.

## Usage

 See some of the examples in the examples/ subdirectory of the tarball.
 Also, check out the included tutorial (in Markdown format) in doc/Tutorial.md
 or view it online on
 <https://github.com/mvidner/ruby-dbus/blob/master/doc/Tutorial.md> .

## License

 Ruby D-Bus is free software; you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2.1 of the License, or (at
 your option) any later version.
