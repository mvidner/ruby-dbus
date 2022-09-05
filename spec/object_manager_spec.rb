#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ObjectManager do
  describe "GetManagedObjects" do
    let(:bus) { DBus::ASessionBus.new }
    let(:service) { bus["org.ruby.service"] }
    let(:obj) { service["/org/ruby/MyInstance"] }
    let(:parent_iface) { obj["org.ruby.TestParent"] }
    let(:om_iface) { obj["org.freedesktop.DBus.ObjectManager"] }

    it "returns the interfaces and properties of currently managed objects" do
      c1_opath = parent_iface.New("child1")
      c2_opath = parent_iface.New("child2")

      parent_iface.Delete(c1_opath)
      expected_gmo = {
        "/org/ruby/MyInstance/child2" => {
          "org.freedesktop.DBus.Introspectable" => {},
          "org.freedesktop.DBus.Properties" => {},
          "org.ruby.TestChild" => { "Name" => "Child2" }
        }
      }
      expect(om_iface.GetManagedObjects).to eq(expected_gmo)

      parent_iface.Delete(c2_opath)
      expect(om_iface.GetManagedObjects).to eq({})
    end
  end
end
