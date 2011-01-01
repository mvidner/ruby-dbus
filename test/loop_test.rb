#!/usr/bin/env ruby
# Test the main loop
require "test/unit"
require "dbus"

class MainLoopTest < Test::Unit::TestCase
  def setup
  end

  def test_main_and_quit_functions
    Thread.new do
      sleep 1
      DBus.main_quit
    end
    DBus.main
  end

  def test_main_and_quit_functions
    Thread.new do
      sleep 1
      DBus.main_quit
    end
    DBus.main
  end

  def test_main_run_and_quit_methods(connections = [])
    loop = DBus::Main.new
    connections.each {|c| loop << c}
    Thread.new do
      sleep 1
      loop.quit
    end
    loop.run
  end

  def test_main_run_and_quit_methods_1
    main_run_and_quit_methods [DBus::ASessionBus.new]
  end

  def test_main_run_and_quit_methods_2
    main_run_and_quit_methods [DBus::ASessionBus.new, DBus::ASessionBus.new]
  end
end
