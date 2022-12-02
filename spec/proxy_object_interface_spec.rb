#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ProxyObjectInterface do
  # TODO: tag tests that need a service, eg "needs-service"
  # TODO: maybe remove this and rely on a packaged tool
  around(:each) do |example|
    with_private_bus do
      with_service_by_activation(&example)
    end
  end

  let(:bus) { DBus::ASessionBus.new }

  context "when calling org.ruby.service" do
    let(:svc) { bus["org.ruby.service"] }

    # This is white box testing, knowing the implementation
    # A better way would be structuring it according to the D-Bus Spec
    # Or testing the service side doing the right thing? (What if our bugs cancel out)
    describe "#define_method_from_descriptor" do
      it "can call a method with multiple OUT arguments" do
        obj = svc["/org/ruby/MyInstance"]
        ifc = obj["org.ruby.SampleInterface"]

        even, odd = ifc.EvenOdd([3, 1, 4, 1, 5, 9, 2, 6])
        expect(even).to eq [4, 2, 6]
        expect(odd).to eq [3, 1, 1, 5, 9]
      end
    end
  end
end
