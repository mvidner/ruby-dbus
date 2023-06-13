#!/usr/bin/env ruby
# frozen_string_literal: true

require "dbus"

d = if ARGV.member?("--system")
      DBus::SystemBus.instance
    else
      DBus::SessionBus.instance
    end
d.proxy.ListNames[0].each do |n|
  puts "\t#{n}"
  qns = d.proxy.ListQueuedOwners(n)[0]
  next if qns.size == 1 && qns.first == n

  qns.each do |qn|
    puts "\t\t#{qn}"
  end
end
