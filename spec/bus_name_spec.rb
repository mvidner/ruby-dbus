#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::BusName do
  describe ".valid?" do
    it "recognizes valid bus names" do
      expect(described_class.valid?("org.freedesktop.DBus")).to be_truthy
      expect(described_class.valid?(":1.42")).to be_truthy
      expect(described_class.valid?("org._7_zip.Archiver")).to be_truthy
    end

    it "recognizes invalid bus names" do
      expect(described_class.valid?("")).to be_falsey
      expect(described_class.valid?("Empty..Component")).to be_falsey
      expect(described_class.valid?(".Empty.First.Component")).to be_falsey
      expect(described_class.valid?("Empty.Last.Component.")).to be_falsey
      expect(described_class.valid?("Invalid.Ch@r@cter")).to be_falsey
      expect(described_class.valid?("/Invalid-Character")).to be_falsey
      long_name = "a.#{"long." * 100}name"
      expect(described_class.valid?(long_name)).to be_falsey
      expect(described_class.valid?("org.7_zip.Archiver")).to be_falsey
    end
  end
end
