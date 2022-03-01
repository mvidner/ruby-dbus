#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ObjectPath do
  describe ".valid?" do
    it "recognizes valid paths" do
      expect(described_class.valid?("/")).to be_truthy
      expect(described_class.valid?("/99Numbers/_And_Underscores/anywhere")).to be_truthy
      long_name = "/A23456789" * 42
      # no 255 character limit for object paths
      expect(described_class.valid?(long_name)).to be_truthy
    end

    it "recognizes invalid paths" do
      expect(described_class.valid?("")).to be_falsey
      expect(described_class.valid?("/Empty//Component")).to be_falsey
      expect(described_class.valid?("/EmptyLastComponent/")).to be_falsey
      expect(described_class.valid?("/Invalid Character")).to be_falsey
      expect(described_class.valid?("/Invalid-Character")).to be_falsey
      expect(described_class.valid?("/InválídCháráctér")).to be_falsey
    end
  end
end
