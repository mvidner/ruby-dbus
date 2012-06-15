#!/usr/bin/env ruby
# Test the bus class
require "test/unit"
require 'rubygems'
require 'nokogiri'
require "dbus"

class BusAndXmlBackendTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
  end

  def test_introspection_reading_rexml
    DBus::IntrospectXMLParser.backend = DBus::IntrospectXMLParser::REXMLParser
    @svc = @bus.service("org.ruby.service")
    obj = @svc.object("/org/ruby/MyInstance")
    obj.default_iface = 'org.ruby.SampleInterface'
    obj.introspect
    assert_nothing_raised do
      assert_equal 42, obj.the_answer[0], "should respond to :the_answer"
    end
    assert_nothing_raised do
      assert_equal "oof", obj["org.ruby.AnotherInterface"].Reverse('foo')[0], "should work with multiple interfaces"
    end
  end

  def test_introspection_reading_nokogiri
    # peek inside the object to see if a cleanup step worked or not
    DBus::IntrospectXMLParser.backend = DBus::IntrospectXMLParser::NokogiriParser
    @svc = @bus.service("org.ruby.service")
    obj = @svc.object("/org/ruby/MyInstance")
    obj.default_iface = 'org.ruby.SampleInterface'
    obj.introspect
    assert_nothing_raised do
      assert_equal 42, obj.the_answer[0], "should respond to :the_answer"
    end
    assert_nothing_raised do
      assert_equal "oof", obj["org.ruby.AnotherInterface"].Reverse('foo')[0], "should work with multiple interfaces"
    end
  end

end
