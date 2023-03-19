#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::Authentication::Client do
  let(:socket) { instance_double("Socket") }
  let(:subject) { described_class.new(socket) }

  before(:each) do
    allow(Process).to receive(:uid).and_return(999)
    allow(subject).to receive(:send_nul_byte)
  end

  def expect_protocol(pairs)
    pairs.each do |we_say, server_says|
      expect(subject).to receive(:write_line).with(we_say)
      next if server_says.nil?

      expect(subject).to receive(:read_line).and_return(server_says)
    end
  end

  context "with ANONYMOUS" do
    let(:subject) { described_class.new(socket, [DBus::Authentication::Anonymous]) }

    it "authentication passes" do
      expect_protocol [
        ["AUTH ANONYMOUS 527562792044427573\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end

  context "with EXTERNAL" do
    let(:subject) { described_class.new(socket, [DBus::Authentication::External]) }

    it "authentication passes" do
      expect_protocol [
        ["AUTH EXTERNAL 393939\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end
end
