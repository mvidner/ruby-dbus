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

  describe "#next_state" do
    it "raises when I forget to handle a state" do
      subject.instance_variable_set(:@state, :Denmark)
      expect { subject.__send__(:next_state, []) }.to raise_error(RuntimeError, /unhandled state :Denmark/)
    end
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
        ["NEGOTIATE_UNIX_FD\r\n", "ERROR not for anonymous\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end

  context "with EXTERNAL" do
    let(:subject) { described_class.new(socket, [DBus::Authentication::External]) }

    it "authentication passes, and address_uuid is set" do
      expect_protocol [
        ["AUTH EXTERNAL 393939\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
      expect(subject.address_uuid).to eq "ffffffffffffffffffffffffffffffff"
    end

    context "when the server says superfluous things before an OK" do
      it "authentication passes" do
        expect_protocol [
          ["AUTH EXTERNAL 393939\r\n", "WOULD_YOU_LIKE_SOME_TEA\r\n"],
          ["ERROR\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
          ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
          ["BEGIN\r\n"]
        ]

        expect { subject.authenticate }.to_not raise_error
      end
    end

    context "when the server messes up NEGOTIATE_UNIX_FD" do
      it "authentication fails orderly" do
        expect_protocol [
          ["AUTH EXTERNAL 393939\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
          ["NEGOTIATE_UNIX_FD\r\n", "I_DONT_NEGOTIATE_WITH_TENORISTS\r\n"]
        ]

        allow(socket).to receive(:close) # want to get rid of this
        # TODO: quote the server error message?
        expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /Unknown server reply/)
      end
    end

    context "when the server replies with ERROR" do
      it "authentication fails orderly" do
        expect_protocol [
          ["AUTH EXTERNAL 393939\r\n", "ERROR something failed\r\n"],
          ["CANCEL\r\n", "REJECTED DBUS_COOKIE_SHA1\r\n"]
        ]

        allow(socket).to receive(:close) # want to get rid of this
        # TODO: quote the server error message?
        expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /exhausted/)
      end
    end
  end

  context "with EXTERNAL without uid" do
    let(:subject) do
      described_class.new(socket, [DBus::Authentication::External, DBus::Authentication::ExternalWithoutUid])
    end

    it "authentication passes" do
      expect_protocol [
        ["AUTH EXTERNAL 393939\r\n", "REJECTED EXTERNAL\r\n"],
        # this succeeds when we connect to a privileged container,
        # where outside-non-root becomes inside-root
        ["AUTH EXTERNAL\r\n", "DATA\r\n"],
        ["DATA\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end

  context "with a rejected mechanism and then EXTERNAL" do
    let(:rejected_mechanism) do
      double("Mechanism", name: "WIMP", call: [:MechContinue, "I expect to be rejected"])
    end

    let(:subject) { described_class.new(socket, [rejected_mechanism, DBus::Authentication::External]) }

    it "authentication eventually passes" do
      expect_protocol [
        [/^AUTH WIMP .*\r\n/, "REJECTED EXTERNAL\r\n"],
        ["AUTH EXTERNAL 393939\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end

  context "with a DATA-using mechanism" do
    let(:mechanism) do
      double("Mechanism", name: "CHALLENGE_ME", call: [:MechContinue, "1"])
    end

    # try it twice to test calling #use_next_mechanism
    let(:subject) { described_class.new(socket, [mechanism, mechanism]) }

    it "authentication fails orderly when the server says ERROR" do
      expect_protocol [
        ["AUTH CHALLENGE_ME 31\r\n", "ERROR something failed\r\n"],
        ["CANCEL\r\n", "REJECTED DBUS_COOKIE_SHA1\r\n"],
        ["AUTH CHALLENGE_ME 31\r\n", "ERROR something failed\r\n"],
        ["CANCEL\r\n", "REJECTED DBUS_COOKIE_SHA1\r\n"]
      ]

      allow(socket).to receive(:close) # want to get rid of this
      # TODO: quote the server error message?
      expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /exhausted/)
    end

    it "authentication fails orderly when the server says ERROR and then changes its mind" do
      expect_protocol [
        ["AUTH CHALLENGE_ME 31\r\n", "ERROR something failed\r\n"],
        ["CANCEL\r\n", "I_CHANGED_MY_MIND please come back\r\n"]
      ]

      allow(socket).to receive(:close) # want to get rid of this
      # TODO: quote the server error message?
      expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /Unknown.*MIND.*REJECTED/)
    end

    it "authentication passes when the server says superfluous things before DATA" do
      expect_protocol [
        ["AUTH CHALLENGE_ME 31\r\n", "WOULD_YOU_LIKE_SOME_TEA\r\n"],
        ["ERROR\r\n", "DATA\r\n"],
        ["DATA 31\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end

    it "authentication passes when the server decides not to need the DATA" do
      expect_protocol [
        ["AUTH CHALLENGE_ME 31\r\n", "OK ffffffffffffffffffffffffffffffff\r\n"],
        ["NEGOTIATE_UNIX_FD\r\n", "AGREE_UNIX_FD\r\n"],
        ["BEGIN\r\n"]
      ]

      expect { subject.authenticate }.to_not raise_error
    end
  end

  context "with a mechanism returning :MechError" do
    let(:fallible_mechanism) do
      double(name: "FALLIBLE", call: [:MechError, "not my best day"])
    end

    let(:subject) { described_class.new(socket, [fallible_mechanism]) }

    it "authentication fails orderly" do
      expect_protocol [
        ["ERROR not my best day\r\n", "REJECTED DBUS_COOKIE_SHA1\r\n"]
      ]

      allow(socket).to receive(:close) # want to get rid of thise
      expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /exhausted/)
    end
  end

  context "with a badly implemented mechanism" do
    let(:buggy_mechanism) do
      double(name: "buggy", call: [:smurf, nil])
    end

    let(:subject) { described_class.new(socket, [buggy_mechanism]) }

    it "authentication fails before protoxol is exchanged" do
      expect(subject).to_not receive(:write_line)
      expect(subject).to_not receive(:read_line)

      expect { subject.authenticate }.to raise_error(DBus::AuthenticationFailed, /smurf/)
    end
  end
end
