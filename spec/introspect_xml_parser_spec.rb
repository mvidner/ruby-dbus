#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe "IntrospectXMLParserTest" do
  it "tests split interfaces" do
    xml = <<-XML
      <node>
        <interface name="org.example.Foo">
          <method name="Dwim"/>
        </interface>
        <interface name="org.example.Bar">
          <method name="Drink"/>
        </interface>
        <interface name="org.example.Foo">
          <method name="Smurf"/>
        </interface>
      </node>
    XML

    interfaces, _subnodes = DBus::IntrospectXMLParser.new(xml).parse

    foo = interfaces.find { |i| i.name == "org.example.Foo" }
    expect(foo.methods.keys.size).to eq(2)
  end
end
