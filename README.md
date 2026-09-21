# Ruby D-Bus

[D-Bus](http://dbus.freedesktop.org) is an interprocess communication
mechanism for Linux.
Ruby D-Bus is a pure Ruby library for writing clients and services for D-Bus.

[![Gem Version][GV img]][Gem Version]
[![Build Status][BS img]][Build Status]
[![Coverage Status][CS img]][Coverage Status]

[Gem Version]: https://rubygems.org/gems/ruby-dbus
[Build Status]: https://github.com/mvidner/ruby-dbus/actions/workflows/ruby.yml?query=branch%3Amaster
[Coverage Status]: https://coveralls.io/r/mvidner/ruby-dbus

[GV img]: https://badge.fury.io/rb/ruby-dbus.png
[BS img]: https://github.com/mvidner/ruby-dbus/actions/workflows/ruby.yml/badge.svg?branch=master
[CS img]: https://coveralls.io/repos/mvidner/ruby-dbus/badge.png?branch=master

## Example

Check whether the system is on battery power
via [UPower](http://upower.freedesktop.org/docs/UPower.html#UPower:OnBattery)

    require "dbus"
    sysbus = DBus.system_bus
    upower_service   = sysbus["org.freedesktop.UPower"]
    upower_object    = upower_service["/org/freedesktop/UPower"]
    upower_interface = upower_object["org.freedesktop.UPower"]
    on_battery       = upower_interface["OnBattery"]
    if on_battery
      puts "The computer IS on battery power."
    else
      puts "The computer IS NOT on battery power."
    end

## Requirements

- Ruby 2.4 or newer.


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

 ## Development

Install the dependencies with `bundle install`.

To run the tests, use `bundle exec rake spec`. Plain `rspec` is not enough
because many tests rely on a common testing bus (see `spec/tools`).

## License

 Ruby D-Bus is free software; you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License as published by the
 Free Software Foundation; either version 2.1 of the License, or (at
 your option) any later version.
