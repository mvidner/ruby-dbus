#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ProxyService do
  context "when a private bus is set up", tag_service: true do
    let(:bus) { DBus::ASessionBus.new }

    describe "#exists?" do
      it "is true for an existing service" do
        svc = bus.service("org.ruby.service")
        svc.object("/").introspect # must activate the service first :-/
        expect(svc.exists?).to be true
      end

      it "is false for a nonexisting service" do
        svc = bus.service("org.ruby.nosuchservice")
        expect(svc.exists?).to be false
      end
    end

    # This method is used by dbus-gui-gtk.
    # Deprecate it? In favor of introspecting the tree gradually
    # or move it to the application code?
    describe "#introspect" do
      it "creates the whole node tree" do
        svc = bus.service("org.ruby.service")
        expect { svc.introspect }.to_not raise_error
        expect(svc.root.dig("org", "ruby", "MyInstance")).to be_a DBus::Node
      end
    end
  end
end
