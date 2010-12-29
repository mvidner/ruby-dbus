#!/usr/bin/env ruby
# Test marshalling variants according to ruby types
require "test/unit"
require "dbus"

class VariantTest < Test::Unit::TestCase
  def setup
    @bus = DBus::ASessionBus.new
    @svc = @bus.service("org.ruby.service")
  end

  def make_variant(a)
    DBus::PacketMarshaller.make_variant(a)
  end

  def test_make_variant_scalar
    # special case: do not fail immediately, marshaller will do that
    assert_equal ["b", nil], make_variant(nil)

    assert_equal ["b", true], make_variant(true)
    # Integers
    # no byte
    assert_equal ["i", 42], make_variant(42)
    # 3_000_000_000 can be u or x.
    # less specific test: just run it thru a loopback
    assert_equal ["x", 3_000_000_000], make_variant(3_000_000_000)
    assert_equal ["x", 5_000_000_000], make_variant(5_000_000_000)
 
    assert_equal ["d", 3.14], make_variant(3.14)

    assert_equal ["s", "foo"], make_variant("foo")
    assert_equal ["s", "bar"], make_variant(:bar)

    # left: strruct, array, dict
    # object path: detect exported objects?, signature

#    # by Ruby types
#    class Foo
#    end
#    make_variant(Foo.new)
# if we don;t understand a class, the error should be informative -> new exception
  end

  def test_make_variant_array
    ai = [1, 2, 3]
#    as = ["one", "two", "three"]
   # which?
#    assert_equal ["ai", [1, 2, 3]], make_variant(ai)
    assert_equal ["av", [["i", 1],
                         ["i", 2],
                         ["i", 3]]], make_variant(ai)
    a0 = []
    assert_equal ["av", []], make_variant(a0)

  end

  def test_make_variant_hash
    h = {"k1" => "v1", "k2" => "v2"}
    assert_equal ["a{sv}", {
                    "k1" => ["s", "v1"],
                    "k2" => ["s", "v2"],
                  }], make_variant(h)
    h0 = {}
    assert_equal ["a{sv}", {}], make_variant(h0)
  end
end
