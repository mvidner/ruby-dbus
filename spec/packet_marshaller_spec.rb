#!/usr/bin/env rspec
# frozen_string_literal: true

require_relative "spec_helper"
require "dbus"
require "ostruct"
require "yaml"

data_dir = File.expand_path("data", __dir__)
marshall_yaml_s = File.read("#{data_dir}/marshall.yaml")
marshall_yaml = YAML.safe_load(marshall_yaml_s)

describe DBus::PacketMarshaller do
  context "marshall.yaml" do
    marshall_yaml.each do |test|
      t = OpenStruct.new(test)
      next if t.marshall == false
      # skip test cases for invalid unmarshalling
      next if t.val.nil?

      # while the marshaller can use only native endianness, skip the other
      endianness = t.end.to_sym

      signature = t.sig
      expected = buffer_from_yaml(t.buf)

      it "writes a '#{signature}' with value #{t.val.inspect} (#{endianness})" do
        subject = described_class.new(endianness: endianness)
        subject.append(signature, t.val)
        expect(subject.packet).to eq(expected)
      end

      it "writes a '#{signature}' with typed value #{t.val.inspect} (#{endianness})" do
        subject = described_class.new(endianness: endianness)
        typed_val = DBus::Data.make_typed(signature, t.val)
        subject.append(signature, typed_val)
        expect(subject.packet).to eq(expected)
      end
    end
  end
end
