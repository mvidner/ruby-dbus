#!/usr/bin/env rspec
# frozen_string_literal: true

# Test marshalling variants according to ruby types
require_relative "spec_helper"
require "dbus"

describe "VariantTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
  end

  def make_variant(val)
    DBus::PacketMarshaller.make_variant(val)
  end

  it "tests make variant scalar" do
    # special case: do not fail immediately, marshaller will do that
    expect(make_variant(nil)).to eq(["b", nil])

    expect(make_variant(true)).to eq(["b", true])
    # Integers
    # no byte
    expect(make_variant(42)).to eq(["i", 42])
    # 3_000_000_000 can be u or x.
    # less specific test: just run it thru a loopback
    expect(make_variant(3_000_000_000)).to eq(["x", 3_000_000_000])
    expect(make_variant(5_000_000_000)).to eq(["x", 5_000_000_000])

    expect(make_variant(3.14)).to eq(["d", 3.14])

    expect(make_variant("foo")).to eq(["s", "foo"])
    expect(make_variant(:bar)).to eq(["s", "bar"])

    # left: strruct, array, dict
    # object path: detect exported objects?, signature

    #    # by Ruby types
    #    class Foo
    #    end
    #    make_variant(Foo.new)
    # if we don;t understand a class, the error should be informative -> new exception
  end

  it "tests make variant array" do
    ai = [1, 2, 3]
    #    as = ["one", "two", "three"]
    # which?
    #    expect(make_variant(ai)).to eq(["ai", [1, 2, 3]])
    expect(make_variant(ai)).to eq(["av", [["i", 1],
                                           ["i", 2],
                                           ["i", 3]]])
    a0 = []
    expect(make_variant(a0)).to eq(["av", []])
  end

  it "tests make variant hash" do
    h = { "k1" => "v1", "k2" => "v2" }
    expect(make_variant(h)).to eq(["a{sv}", {
                                    "k1" => ["s", "v1"],
                                    "k2" => ["s", "v2"]
                                  }])
    h0 = {}
    expect(make_variant(h0)).to eq(["a{sv}", {}])
  end
end
