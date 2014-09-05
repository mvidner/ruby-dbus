#!/usr/bin/env rspec
# Test the bus class
require_relative "spec_helper"

require 'rubygems'
require 'nokogiri'
require "dbus"

describe "BusAndXmlBackendTest" do
  before(:each) do
    @bus = DBus::ASessionBus.new
  end

  it "tests introspection reading rexml" do
    DBus::IntrospectXMLParser.backend = DBus::IntrospectXMLParser::REXMLParser
    @svc = @bus.service("org.ruby.service")
    obj = @svc.object("/org/ruby/MyInstance")
    obj.default_iface = 'org.ruby.SampleInterface'
    obj.introspect
    # "should respond to :the_answer"
    expect(obj.the_answer[0]).to eq(42)
    # "should work with multiple interfaces"
    expect(obj["org.ruby.AnotherInterface"].Reverse('foo')[0]).to eq("oof")
  end

  it "tests introspection reading nokogiri" do
    # peek inside the object to see if a cleanup step worked or not
    DBus::IntrospectXMLParser.backend = DBus::IntrospectXMLParser::NokogiriParser
    @svc = @bus.service("org.ruby.service")
    obj = @svc.object("/org/ruby/MyInstance")
    obj.default_iface = 'org.ruby.SampleInterface'
    obj.introspect
    # "should respond to :the_answer"
    expect(obj.the_answer[0]).to eq(42)
    # "should work with multiple interfaces"
    expect(obj["org.ruby.AnotherInterface"].Reverse('foo')[0]).to eq("oof")
  end

end
