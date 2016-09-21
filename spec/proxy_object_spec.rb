#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

describe DBus::ProxyObject do
  around(:each) do |example|
    with_private_bus do
      with_service_by_activation(&example)
    end
  end

  let(:bus) { DBus::ASessionBus.new }

  context "when calling org.ruby.service" do
    let(:svc) { bus["org.ruby.service"] }

    context "when introspection mode is not specified" do
      describe "#bounce_variant" do
        it "works without an explicit #introspect call" do
          obj = svc["/org/ruby/MyInstance"]
          ifc = obj["org.ruby.SampleInterface"]
          expect(ifc.bounce_variant(42)).to be_eql 42
        end

        it "works with one #introspect call" do
          obj = svc["/org/ruby/MyInstance"]
          obj.introspect
          ifc = obj["org.ruby.SampleInterface"]
          expect(ifc.bounce_variant(42)).to be_eql 42
        end

        it "works with two #introspect calls" do
          obj = svc["/org/ruby/MyInstance"]
          obj.introspect
          obj.introspect
          ifc = obj["org.ruby.SampleInterface"]
          expect(ifc.bounce_variant(42)).to be_eql 42
        end
      end
    end
  end
end
