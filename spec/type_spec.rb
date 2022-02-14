#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus do
  describe ".type" do
    ["i", "ai", "a(ii)", "aai"].each do |s|
      it "parses some type #{s}" do
        expect(DBus.type(s).to_s).to be_eql s
      end
    end

    ["aa", "(ii", "ii)", "hrmp"].each do |s|
      it "raises exception for invalid type #{s}" do
        expect { DBus.type(s).to_s }.to raise_error DBus::Type::SignatureException
      end
    end
  end
end
