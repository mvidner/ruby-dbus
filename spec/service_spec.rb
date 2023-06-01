#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

# FIXME: rename to object_server_spec and move more tests here

describe DBus::ObjectServer do
  let(:bus) { DBus::ASessionBus.new }
  # This is the client role, but the server role API is bad
  # and for the one test there is no difference
  let(:server) { bus.object_server }

  describe "#descendants_for" do
    it "raises for not existing path" do
      expect { server.descendants_for("/notthere") }.to raise_error(ArgumentError)
    end
  end
end
