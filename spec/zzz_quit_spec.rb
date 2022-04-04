#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe "Quit the service" do
  it "Tells the service to quit and waits, to collate coverage data" do
    session_bus = DBus::ASessionBus.new
    @svc = session_bus.service("org.ruby.service")
    @obj = @svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.SampleInterface"
    @obj.quit
    sleep 3
  end
end
