#! /usr/bin/env ruby
require 'rubygems'  # Not needed since Ruby 1.9
require 'dbus'      # The gem is 'ruby-dbus' but the require is 'dbus'

# Connect to a well-known address. Most apps need only one of them.
mybus  = DBus.session_bus
sysbus = DBus.system_bus
