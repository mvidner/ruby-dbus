#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"

describe DBus::ObjectServer do
  let(:bus) { DBus::ASessionBus.new }
  let(:server) { bus.object_server }

  describe "#descendants_for" do
    it "raises for not existing path" do
      expect { server.descendants_for("/notthere") }.to raise_error(ArgumentError, /notthere doesn't exist/)
    end
  end

  # tag_bus MEANS that the test needs a session bus
  # tag_service MEANS that it needs a session bus with our testing services

  describe "#export, #object, #[]", tag_bus: true do
    it "object and [] return the object if it was exported" do
      path = "/org/ruby/Foo"
      obj = DBus::Object.new(path)
      server.export(obj)
      expect(server.object(path)).to be_equal(obj)
      expect(server[path]).to be_equal(obj)
    end

    it "object and [] return nil if the path was not found or has no object" do
      path = "/org/ruby/Bar"
      obj = DBus::Object.new(path)
      server.export(obj)

      path2 = "/org/ruby/nosuch"
      expect(server.object(path2)).to be_nil
      expect(server[path2]).to be_nil

      path3 = "/org"
      expect(server.object(path3)).to be_nil
      expect(server[path3]).to be_nil
    end
  end

  describe "#export", tag_bus: true do
    context "when exporting at a path where an object exists already" do
      let(:path) { "/org/ruby/Same" }
      let(:obj1) do
        o = DBus::Object.new(path)
        o.define_singleton_method(:which) { 1 }
        o
      end
      let(:obj2) do
        o = DBus::Object.new(path)
        o.define_singleton_method(:which) { 2 }
        o
      end

      it "raises an error" do
        server.export(obj1)
        expect { server.export(obj2) }.to raise_error(RuntimeError, /there is already an object/)
      end
    end
  end

  describe "#unexport", tag_bus: true do
    before(:each) do
      bus = DBus::ASessionBus.new
      @svc = bus.object_server
    end

    it "returns the unexported leaf object" do
      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect(@svc.unexport(obj)).to be_equal(obj)
    end

    it "returns the unexported leaf object, if specified by its path" do
      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect(@svc.unexport(obj.path)).to be_equal(obj)

      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect(@svc.unexport(DBus::ObjectPath.new(obj.path))).to be_equal(obj)
    end

    it "returns false if the object was never exported" do
      obj = DBus::Object.new "/org/ruby/Foo"
      expect(@svc.unexport(obj)).to be false
    end

    it "raises false if the path has no node" do
      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect { @svc.unexport("/org/ruby/NotFoo") }.to raise_error(ArgumentError)
      @svc.unexport obj
    end

    it "raises false if the path has no object" do
      obj = DBus::Object.new "/org/ruby/Foo"
      @svc.export obj
      expect { @svc.unexport("/org/ruby") }.to raise_error(ArgumentError)
      @svc.unexport obj
    end

    it "raises when argument is not usable" do
      expect { @svc.unexport(:foo) }.to raise_error(ArgumentError)
    end

    context "/child_of_root" do
      it "returns the unexported object" do
        obj = DBus::Object.new "/child_of_root"
        @svc.export obj
        expect(@svc.unexport(obj)).to be_equal(obj)
      end
    end

    context "/ (root)" do
      it "returns the unexported object" do
        obj = DBus::Object.new "/"
        @svc.export obj
        expect(@svc.unexport(obj)).to be_equal(obj)
      end
    end

    context "not a leaf object" do
      it "maintains objects on child paths" do
        obj = DBus::Object.new "/org/ruby"
        @svc.export obj
        obj2 = DBus::Object.new "/org/ruby/Foo"
        @svc.export obj2

        @svc.unexport(obj)
        expect(@svc.object("/org/ruby/Foo")).to be_a DBus::Object
      end
    end
  end
end
