#!/usr/bin/env ruby
# Test the type class
require "test/unit"
require "dbus"

class TypeTest < Test::Unit::TestCase
  def test_costants_are_defined
    assert_equal DBus::Type::BYTE, ?y
    assert_equal DBus::Type::BOOLEAN, ?b
    #etc..
  end

  def test_parsing
    %w{i ai a(ii) aai}.each do |s|
      assert_equal s, DBus::type(s).to_s
    end

    %w{aa (ii ii) hrmp}.each do |s|
      assert_raise(DBus::Type::SignatureException) { DBus::type(s) }
    end
  end
end
