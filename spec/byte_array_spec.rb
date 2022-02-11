#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"

require "dbus"

describe "ByteArrayTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
    @obj = @svc.object("/org/ruby/MyInstance")
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  it "tests passing byte array" do
    data = [0, 77, 255]
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq(data)
  end

  it "tests passing byte array from string" do
    data = "AAA"
    result = @obj.mirror_byte_array(data).first
    expect(result).to eq([65, 65, 65])
  end

  it "tests passing byte array from hash" do
    # Hash is an Enumerable, but is caught earlier
    data = { "this will" => "fail" }
    expect { @obj.mirror_byte_array(data).first }.to raise_error(DBus::TypeException)
  end

  it "tests passing byte array from nonenumerable" do
    data = Time.now
    expect { @obj.mirror_byte_array(data).first }.to raise_error(DBus::TypeException)
  end
end
