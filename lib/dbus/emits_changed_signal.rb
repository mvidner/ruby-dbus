# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2022 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # Describes the behavior of PropertiesChanged signal, for a single property
  # or for an entire interface.
  #
  # The possible values are:
  #
  # - *true*: the signal is emitted with the value included.
  # - *:invalidates*: the signal is emitted but the value is not included
  #   in the signal.
  # - *:const*: the property never changes value during the lifetime
  #   of the object it belongs to, and hence the signal
  #   is never emitted for it (but clients can cache the value)
  # - *false*: the signal won't be emitted (clients should re-Get the property value)
  #
  # The default is:
  # - for an interface: *true*
  # - for a property: what the parent interface specifies
  #
  # @see DBus::Object.emits_changed_signal
  # @see DBus::Object.dbus_attr_accessor
  # @see https://dbus.freedesktop.org/doc/dbus-specification.html#introspection-format
  #
  # Immutable once constructed.
  class EmitsChangedSignal
    # @return [true,false,:const,:invalidates]
    attr_reader :value

    # @param value [true,false,:const,:invalidates,nil]
    #   See class-level description above, {EmitsChangedSignal}.
    # @param interface [Interface,nil]
    #   If the (property-level) *value* is unspecified (nil), this is the
    #   containing {Interface} to get the value from.
    def initialize(value, interface: nil)
      if value.nil?
        raise ArgumentError, "Both arguments are nil" if interface.nil?

        @value = interface.emits_changed_signal.value
      else
        expecting = [true, false, :const, :invalidates]
        unless expecting.include?(value)
          raise ArgumentError, "Expecting one of #{expecting.inspect}. Seen #{value.inspect}"
        end

        @value = value
      end

      freeze
    end

    # Return introspection XML string representation
    # @return [String]
    def to_xml
      return "" if @value == true

      "    <annotation name=\"org.freedesktop.DBus.Property.EmitsChangedSignal\" value=\"#{@value}\"/>\n"
    end

    def to_s
      @value.to_s
    end

    def ==(other)
      if other.is_a?(self.class)
        other.value == @value
      else
        other == value
      end
    end
    alias eql? ==

    DEFAULT_ECS = EmitsChangedSignal.new(true)
  end
end
