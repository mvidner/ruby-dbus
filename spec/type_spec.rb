#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

describe DBus do
  describe ".type" do
    %w{i ai a(ii) aai}.each do |s|
      it "parses some type #{s}" do
        expect(DBus::type(s).to_s).to be_eql s
      end
    end

    %w{aa (ii ii) hrmp}.each do |s|
      it "raises exception for invalid type #{s}" do
        expect {DBus::type(s).to_s}.to raise_error DBus::Type::SignatureException
      end
    end
  end
end
