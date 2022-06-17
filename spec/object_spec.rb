#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

class ObjectTest < DBus::Object
  T = DBus::Type unless const_defined? "T"

  dbus_interface "org.ruby.ServerTest" do
    dbus_attr_writer :write_me, T::Struct[String, String]
  end
end

describe DBus::Object do
  describe ".dbus_attr_writer" do
    describe "the declared assignment method" do
      # Slightly advanced RSpec:
      # https://rspec.info/documentation/3.9/rspec-expectations/RSpec/Matchers.html#satisfy-instance_method
      let(:a_struct_in_a_variant) do
        satisfying { |x| x.is_a?(DBus::Data::Variant) && x.member_type.to_s == "(ss)" }
        # ^ This formatting keeps the matcher on a single line
        # which enables RSpec to cite it if it fails, instead of saying "block".
      end

      it "emits PropertyChanged with correctly typed argument" do
        obj = ObjectTest.new("/test")
        expect(obj).to receive(:PropertiesChanged).with(
          "org.ruby.ServerTest",
          {
            "WriteMe" => a_struct_in_a_variant
          },
          []
        )
        # bug: call PC with simply the assigned value,
        # which will need type guessing
        obj.write_me = ["two", "strings"]
      end
    end
  end
end
