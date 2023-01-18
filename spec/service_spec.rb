#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe "DBus::Service (server role)" do
  let(:bus) { DBus::ASessionBus.new }
  # This is the client role, but the server role API is bad
  # and for the one test there is no difference
  let(:service) { bus["org.ruby.service"] }

  describe "#descendants_for" do
    it "raises for not existing path" do
      expect { service.descendants_for("/notthere") }.to raise_error(ArgumentError)
    end
  end
end
