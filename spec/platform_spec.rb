#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::Platform do
  describe ".macos?" do
    # code coverage chasing, as other tests mock it out
    it "doesn't crash" do
      expect { described_class.macos? }.to_not raise_error
    end
  end
end
