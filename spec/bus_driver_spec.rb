#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

describe DBus::Service do
  context "when a private bus is set up" do
    around(:each) do |example|
      with_private_bus do
        with_service_by_activation(&example)
      end
    end

    let(:bus) { DBus::ASessionBus.new }

    describe "#exists?" do
      it "is true for an existing service" do
        svc = bus.service("org.ruby.service")
        svc.object("/").introspect # must activate the service first :-/
        expect(svc.exists?).to be_true
      end

      it "is false for a nonexisting service" do
        svc = bus.service("org.ruby.nosuchservice")
        expect(svc.exists?).to be_false
      end
    end
  end
end
