#!/usr/bin/env ruby
require "test/unit"
require "dbus"

class ValueTest < Test::Unit::TestCase
  def setup
    session_bus = DBus::ASessionBus.new
    svc = session_bus.service("org.ruby.service")
    @obj = svc.object("/org/ruby/MyInstance")
    @obj.introspect                  # necessary
    @obj.default_iface = "org.ruby.SampleInterface"
  end

  def test_passing_an_array_through_a_variant
    # old explicit typing
    @obj.test_variant(["as", ["coucou", "kuku"]])
    # automatic typing
    @obj.test_variant(["coucou", "kuku"])
    @obj.test_variant(["saint", "was that a word or a signature?"])
  end

  def test_bouncing_a_variant
    assert_equal "cuckoo", @obj.bounce_variant("cuckoo")[0]
    assert_equal ["coucou", "kuku"], @obj.bounce_variant(["coucou", "kuku"])[0]
    assert_equal [], @obj.bounce_variant([])[0]
    empty_hash = {}
    assert_equal empty_hash, @obj.bounce_variant(empty_hash)[0]
  end
  
  # these are ambiguous
  def test_pairs_with_a_string
    
    # deprecated
    assert_equal "foo", @obj.bounce_variant(["s", "foo"])[0]
    
    assert_equal "foo", @obj.bounce_variant(DBus.variant("s", "foo"))[0]
    assert_equal "foo", @obj.bounce_variant([DBus.type("s"), "foo"])[0]

    # does not work, because the server side forgets the explicit typing
#    assert_equal ["s", "foo"], @obj.bounce_variant(["av", ["s", "foo"]])[0]
#    assert_equal ["s", "foo"], @obj.bounce_variant(["as", ["s", "foo"]])[0]

    # instead, use this to demonstrate that the variant is passed as expected
    assert_equal 4, @obj.variant_size(["s", "four"])[0]
    # "av" is the simplest thing that will work,
    # shifting the heuristic from a pair to the individual items
    assert_equal 2, @obj.variant_size(["av", ["s", "four"]])[0]
  end

  def test_marshalling_an_array_of_variants
    # https://trac.luon.net/ruby-dbus/ticket/30
    @obj.default_iface = "org.ruby.Ticket30"
    choices = []
    choices << ['s', 'Plan A']
    choices << ['s', 'Plan B']
    # old explicit typing
    assert_equal "Do Plan A", @obj.Sybilla(choices)[0]
    # automatic typing
    assert_equal "Do Plan A", @obj.Sybilla(["Plan A", "Plan B"])[0]
  end

  def test_service_returning_nonarray
    # "warning: default `to_a' will be obsolete"
    @obj.the_answer
  end
end
