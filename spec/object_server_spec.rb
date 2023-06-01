#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ObjectServer do
  let(:bus) { DBus::ASessionBus.new }
  # This is the client role, but the server role API is bad
  # and for the one test there is no difference
  let(:server) { bus.object_server }

  describe "#descendants_for" do
    it "raises for not existing path" do
      expect { server.descendants_for("/notthere") }.to raise_error(ArgumentError, /notthere doesn't exist/)
    end
  end

  # tag_bus MEANS that the test needs a session bus
  # tag_service MEANS that it needs a session bus with our testing services

  describe "#unexport", tag_bus: true do
    before(:each) do
      @bus = DBus::ASessionBus.new
      @svc = @bus.request_service "org.ruby.server-test"
    end

    after(:each) do
      @bus.proxy.ReleaseName "org.ruby.server-test"
    end

    it "returns the unexported object" do
      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect(@svc.unexport(obj)).to be_a DBus::Object
    end

    it "returns false if the object was never exported" do
      obj = DBus::Object.new "/org/ruby/Foo"
      expect(@svc.unexport(obj)).to be false
    end

    it "raises when argument is not a DBus::Object" do
      path = "/org/ruby/Foo"
      obj = DBus::Object.new(path)
      expect { @svc.unexport(path) }.to raise_error(ArgumentError)
    end
  end
end
