#!/usr/bin/env rspec
require_relative "spec_helper"
require "dbus"

describe "PropertyTest" do
  before(:each) do
    @session_bus = DBus::ASessionBus.new
    @svc = @session_bus.service("org.ruby.service")
    @obj = @svc.object("/org/ruby/MyInstance")
    @iface = @obj["org.ruby.SampleInterface"]
  end

  it "tests property reading" do
    expect(@iface["ReadMe"]).to eq("READ ME")
  end

  it "tests property reading on a V1 object" do
    obj = @svc["/org/ruby/MyInstance"]
    iface = obj["org.ruby.SampleInterface"]

    expect(iface["ReadMe"]).to eq("READ ME")
  end

  it "gets an error when reading a property whose implementation raises" do
    expect { @iface["Explosive"] }.to raise_error(DBus::Error, /Something failed/)
  end

  it "tests property nonreading" do
    expect { @iface["WriteMe"] }.to raise_error(DBus::Error, /not readable/)
  end

  it "tests property writing" do
    @iface["ReadOrWriteMe"] = "VALUE"
    expect(@iface["ReadOrWriteMe"]).to eq("VALUE")
  end

  # https://github.com/mvidner/ruby-dbus/pull/19
  it "tests service select timeout", slow: true do
    @iface["ReadOrWriteMe"] = "VALUE"
    expect(@iface["ReadOrWriteMe"]).to eq("VALUE")
    # wait for the service to become idle
    sleep 6
    # fail:  "Property value changed; perhaps the service died and got restarted"
    expect(@iface["ReadOrWriteMe"]).to eq("VALUE")
  end

  it "tests property nonwriting" do
    expect { @iface["ReadMe"] = "WROTE" }.to raise_error(DBus::Error, /not writable/)
  end

  it "tests get all" do
    all = @iface.all_properties
    expect(all.keys.sort).to eq(["ReadMe", "ReadOrWriteMe"])
  end

  it "tests get all on a V1 object" do
    obj = @svc["/org/ruby/MyInstance"]
    iface = obj["org.ruby.SampleInterface"]

    all = iface.all_properties
    expect(all.keys.sort).to eq(["ReadMe", "ReadOrWriteMe"])
  end

  it "tests unknown property reading" do
    expect { @iface["Spoon"] }.to raise_error(DBus::Error, /not found/)
  end

  it "tests unknown property writing" do
    expect { @iface["Spoon"] = "FPRK" }.to raise_error(DBus::Error, /not found/)
  end

  it "errors for a property on an unknown interface" do
    # our idiomatic way would error out on interface lookup already,
    # so do it the low level way
    prop_if = @obj[DBus::PROPERTY_INTERFACE]
    expect { prop_if.Get("org.ruby.NoSuchInterface", "SomeProperty") }.to raise_error(DBus::Error) do |e|
      expect(e.name).to match(/UnknownProperty/)
      expect(e.message).to match(/no such interface/)
    end
  end

  it "errors for GetAll on an unknown interface" do
    # no idiomatic way?
    # so do it the low level way
    prop_if = @obj[DBus::PROPERTY_INTERFACE]
    expect { prop_if.GetAll("org.ruby.NoSuchInterface") }.to raise_error(DBus::Error) do |e|
      expect(e.name).to match(/UnknownProperty/)
      expect(e.message).to match(/no such interface/)
    end
  end

  it "receives a PropertiesChanged signal", slow: true do
    received = {}

    # TODO: for client side, provide a helper on_properties_changed,
    # or automate it even more in ProxyObject, ProxyObjectInterface
    prop_if = @obj[DBus::PROPERTY_INTERFACE]
    prop_if.on_signal("PropertiesChanged") do |_interface_name, changed_props, _invalidated_props|
      received.merge!(changed_props)
    end

    @iface["ReadOrWriteMe"] = "VALUE"

    # loop to process the signal. complicated :-( see signal_spec.rb
    loop = DBus::Main.new
    loop << @session_bus
    quitter = Thread.new do
      sleep 1
      loop.quit
    end
    loop.run
    # quitter has told loop.run to quit
    quitter.join

    expect(received["ReadOrWriteMe"]).to eq("VALUE")
  end
end
