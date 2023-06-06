# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2022 José Iván López González
# Copyright (C) 2022 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # A mixin for {DBus::Object} implementing
  # {https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces-objectmanager
  # org.freedesktop.DBus.ObjectManager}.
  #
  # {ObjectServer#export} and {ObjectServer#unexport} will look for an ObjectManager
  # parent in the path hierarchy. If found, it will emit InterfacesAdded
  # or InterfacesRemoved, as appropriate.
  module ObjectManager
    OBJECT_MANAGER_INTERFACE = "org.freedesktop.DBus.ObjectManager"

    # Implements `the GetManagedObjects` method.
    # @return [Hash{ObjectPath => Hash{String => Hash{String => Data::Base}}}]
    #   object -> interface -> property -> value
    def managed_objects
      descendant_objects = object_server.descendants_for(path)
      descendant_objects.each_with_object({}) do |obj, hash|
        hash[obj.path] = obj.interfaces_and_properties
      end
    end

    # {ObjectServer#export} will call this for you to emit the `InterfacesAdded` signal.
    # @param object [DBus::Object]
    # @return [void]
    def object_added(object)
      InterfacesAdded(object.path, object.interfaces_and_properties)
    end

    # {ObjectServer#unexport} will call this for you to emit the `InterfacesRemoved` signal.
    # @param object [DBus::Object]
    # @return [void]
    def object_removed(object)
      InterfacesRemoved(object.path, object.intfs.keys)
    end

    # Module#included, a hook for `include ObjectManager`, declares its dbus_interface.
    def self.included(base)
      base.class_eval do
        dbus_interface OBJECT_MANAGER_INTERFACE do
          dbus_method :GetManagedObjects, "out res:a{oa{sa{sv}}}" do
            [managed_objects]
          end

          dbus_signal :InterfacesAdded, "object:o, interfaces_and_properties:a{sa{sv}}"
          dbus_signal :InterfacesRemoved, "object:o, interfaces:as"
        end
      end
    end
  end
end
