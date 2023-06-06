#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

class ObjectTest < DBus::Object
  T = DBus::Type unless const_defined? "T"

  dbus_interface "org.ruby.ServerTest" do
    dbus_attr_writer :write_me, T::Struct[String, String]

    attr_accessor :read_only_for_dbus

    dbus_reader :read_only_for_dbus, T::STRING, emits_changed_signal: :invalidates
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

  describe ".dbus_accessor" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_accessor :foo, DBus::Type::STRING
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end
  end

  describe ".dbus_reader" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_reader :foo, DBus::Type::STRING
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end

    it "fails when the signature is invalid" do
      expect do
        ObjectTest.instance_exec do
          dbus_interface "org.ruby.ServerTest" do
            dbus_reader :foo2, "!"
          end
        end
      end.to raise_error(DBus::Type::SignatureException)
    end
  end

  describe ".dbus_reader, when paired with attr_accessor" do
    describe "the declared assignment method" do
      it "emits PropertyChanged" do
        obj = ObjectTest.new("/test")
        expect(obj).to receive(:PropertiesChanged).with(
          "org.ruby.ServerTest",
          {},
          ["ReadOnlyForDbus"]
        )
        obj.read_only_for_dbus = "myvalue"
      end
    end
  end

  describe ".dbus_writer" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_writer :foo, DBus::Type::STRING
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end
  end

  describe ".dbus_watcher" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_watcher :foo
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end
  end

  describe ".dbus_method" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_method :foo do
          end
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end
  end

  describe ".dbus_signal" do
    it "can only be used within a dbus_interface" do
      expect do
        ObjectTest.instance_exec do
          dbus_signal :signal_without_interface
        end
      end.to raise_error(DBus::Object::UndefinedInterface)
    end

    it "cannot be named with a bang" do
      expect do
        ObjectTest.instance_exec do
          dbus_interface "org.ruby.ServerTest" do
            # a valid Ruby symbol but an invalid DBus name; Ticket#38
            dbus_signal :signal_with_a_bang!
          end
        end
      end.to raise_error(DBus::InvalidMethodName)
    end
  end

  describe ".emits_changed_signal" do
    it "raises UndefinedInterface when so" do
      expect { ObjectTest.emits_changed_signal = false }
        .to raise_error DBus::Object::UndefinedInterface
    end

    it "assigns to the current interface" do
      ObjectTest.instance_exec do
        dbus_interface "org.ruby.Interface" do
          self.emits_changed_signal = false
        end
      end
      ecs = ObjectTest.intfs["org.ruby.Interface"].emits_changed_signal
      expect(ecs).to eq false
    end

    it "only can be assigned once" do
      expect do
        Class.new(DBus::Object) do
          dbus_interface "org.ruby.Interface" do
            self.emits_changed_signal = false
            self.emits_changed_signal = :invalidates
          end
        end
      end.to raise_error(RuntimeError, /assigned more than once/)
    end
  end

  # coverage obsession
  describe "#dispatch" do
    it "survives being called with a non-METHOD_CALL, doing nothing" do
      obj = ObjectTest.new("/test")
      msg = DBus::MethodReturnMessage.new
      expect { obj.dispatch(msg) }.to_not raise_error
    end
  end

  describe "#emit" do
    context "before the object has been exported" do
      it "raises an explanatory error" do
        obj = ObjectTest.new("/test")

        intf = DBus::Interface.new("org.example.Test")
        signal = DBus::Signal.new("Ring")
        expect { obj.emit(intf, signal) }
          .to raise_error(
            RuntimeError,
            %r{Cannot emit signal org.example.Test.Ring before /test is exported}
          )
      end
    end
  end
end
