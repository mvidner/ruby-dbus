#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::Node do
  describe "#inspect" do
    # the behavior needs improvement
    it "shows the node, poorly" do
      parent = described_class.new("parent")
      parent.object = DBus::Object.new("/parent")

      3.times do |i|
        child_name = "child#{i}"
        child = described_class.new(child_name)
        parent[child_name] = child
      end

      expect(parent.inspect).to match(/<DBus::Node [0-9a-f]+ {child0 => {},child1 => {},child2 => {}}>/)
    end
  end

  describe "#descendant_objects" do
    let(:manager_path) { "/org/example/FooManager" }
    let(:child_paths) do
      [
        # note that "/org/example/FooManager/good"
        # is a path under a managed object but there is no object there
        "/org/example/FooManager/good/1",
        "/org/example/FooManager/good/2",
        "/org/example/FooManager/good/3",
        "/org/example/FooManager/bad/1",
        "/org/example/FooManager/bad/2"
      ]
    end

    let(:non_child_paths) do
      [
        "/org/example/BarManager/good/1",
        "/org/example/BarManager/good/2"
      ]
    end

    context "on the bus" do
      let(:bus) { DBus::ASessionBus.new }
      let(:service) { bus.request_service("org.ruby.service") }

      before do
        service.export(DBus::Object.new(manager_path))
        non_child_paths.each do |p|
          service.export(DBus::Object.new(p))
        end
      end

      it "returns just the descendants of the specified objects" do
        child_exported_objects = child_paths.map { |p| DBus::Object.new(p) }
        child_exported_objects.each { |obj| service.export(obj) }

        node = service.get_node(manager_path, create: false)
        expect(node.descendant_objects).to eq child_exported_objects
      end
    end
  end
end
