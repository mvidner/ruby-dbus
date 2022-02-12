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
end
