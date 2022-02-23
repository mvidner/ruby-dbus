#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe "ValueTest" do
  before(:each) do
    session_bus = DBus::ASessionBus.new
    @svc = session_bus.service("org.ruby.service")
    @obj = @svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  it "tests passing an array of structs through a variant" do
    triple = ["a(uuu)", []]
    @obj.test_variant(triple)
    quadruple = ["a(uuuu)", []] # a(uuu) works fine
    # The bus disconnects us because of malformed message,
    # code 12: DBUS_INVALID_TOO_MUCH_DATA
    @obj.test_variant(quadruple)
  end

  it "tests passing an array through a variant" do
    # old explicit typing
    @obj.test_variant(["as", ["coucou", "kuku"]])
    # automatic typing
    @obj.test_variant(["coucou", "kuku"])
    @obj.test_variant(["saint", "was that a word or a signature?"])
  end

  it "tests bouncing a variant" do
    expect(@obj.bounce_variant("cuckoo")[0]).to eq("cuckoo")
    expect(@obj.bounce_variant(["coucou", "kuku"])[0]).to eq(["coucou", "kuku"])
    expect(@obj.bounce_variant([])[0]).to eq([])
    empty_hash = {}
    expect(@obj.bounce_variant(empty_hash)[0]).to eq(empty_hash)
  end

  it "retrieves a single return value with API V1" do
    obj = @svc["/org/ruby/MyInstance"]
    obj.default_iface = "org.ruby.SampleInterface"

    expect(obj.bounce_variant("cuckoo")).to eq("cuckoo")
    expect(obj.bounce_variant(["coucou", "kuku"])).to eq(["coucou", "kuku"])
    expect(obj.bounce_variant([])).to eq([])
    empty_hash = {}
    expect(obj.bounce_variant(empty_hash)).to eq(empty_hash)
  end

  # these are ambiguous
  it "tests pairs with a string" do
    # deprecated
    expect(@obj.bounce_variant(["s", "foo"])[0]).to eq("foo")

    expect(@obj.bounce_variant(DBus.variant("s", "foo"))[0]).to eq("foo")
    expect(@obj.bounce_variant([DBus.type("s"), "foo"])[0]).to eq("foo")

    # does not work, because the server side forgets the explicit typing
    #    assert_equal ["s", "foo"], @obj.bounce_variant(["av", ["s", "foo"]])[0]
    #    assert_equal ["s", "foo"], @obj.bounce_variant(["as", ["s", "foo"]])[0]

    # instead, use this to demonstrate that the variant is passed as expected
    expect(@obj.variant_size(["s", "four"])[0]).to eq(4)
    # "av" is the simplest thing that will work,
    # shifting the heuristic from a pair to the individual items
    expect(@obj.variant_size(["av", ["s", "four"]])[0]).to eq(2)
  end

  it "tests marshalling an array of variants" do
    # https://trac.luon.net/ruby-dbus/ticket/30
    @obj.default_iface = "org.ruby.Ticket30"
    choices = []
    choices << ["s", "Plan A"]
    choices << ["s", "Plan B"]
    # old explicit typing
    expect(@obj.Sybilla(choices)[0]).to eq("Do Plan A")
    # automatic typing
    expect(@obj.Sybilla(["Plan A", "Plan B"])[0]).to eq("Do Plan A")
  end

  it "tests service returning nonarray" do
    # "warning: default `to_a' will be obsolete"
    @obj.the_answer
  end

  it "tests multibyte string" do
    str = @obj.multibyte_string[0]
    expect(str).to eq("あいうえお")
  end

  it "aligns short integers correctly" do
    expect(@obj.i16_plus(10, -30)[0]).to eq(-20)
  end

  context "structs" do
    it "they are returned as FROZEN arrays" do
      struct = @obj.Coordinates[0]
      expect(struct).to be_an(Array)
      expect(struct).to be_frozen
    end

    it "they are returned also from structs" do
      struct = @obj.Coordinates2[0]
      expect(struct).to be_an(Array)
      expect(struct).to be_frozen
    end
  end
end
