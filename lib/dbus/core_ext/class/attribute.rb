# frozen_string_literal: true
# copied from activesupport/core_ext from Rails, MIT license
# https://github.com/rails/rails/tree/9794e85351243cac6d4e78adaba634b8e4ecad0a/activesupport/lib/active_support/core_ext

require_relative "../module/redefine_method"

class Class
  # Declare a class-level attribute whose value is inheritable by subclasses.
  # Subclasses can change their own value and it will not impact parent class.
  #
  # ==== Examples
  #
  #   class Base
  #     my_class_attribute :setting
  #   end
  #
  #   class Subclass < Base
  #   end
  #
  #   Base.setting = true
  #   Subclass.setting            # => true
  #   Subclass.setting = false
  #   Subclass.setting            # => false
  #   Base.setting                # => true
  #
  # In the above case as long as Subclass does not assign a value to setting
  # by performing <tt>Subclass.setting = _something_</tt>, <tt>Subclass.setting</tt>
  # would read value assigned to parent class. Once Subclass assigns a value then
  # the value assigned by Subclass would be returned.
  #
  # This matches normal Ruby method inheritance: think of writing an attribute
  # on a subclass as overriding the reader method. However, you need to be aware
  # when using +class_attribute+ with mutable structures as +Array+ or +Hash+.
  # In such cases, you don't want to do changes in place. Instead use setters:
  #
  #   Base.setting = []
  #   Base.setting                # => []
  #   Subclass.setting            # => []
  #
  #   # Appending in child changes both parent and child because it is the same object:
  #   Subclass.setting << :foo
  #   Base.setting               # => [:foo]
  #   Subclass.setting           # => [:foo]
  #
  #   # Use setters to not propagate changes:
  #   Base.setting = []
  #   Subclass.setting += [:foo]
  #   Base.setting               # => []
  #   Subclass.setting           # => [:foo]
  #
  # For convenience, an instance predicate method is defined as well.
  # To skip it, pass <tt>instance_predicate: false</tt>.
  #
  #   Subclass.setting?       # => false
  #
  # Instances may overwrite the class value in the same way:
  #
  #   Base.setting = true
  #   object = Base.new
  #   object.setting          # => true
  #   object.setting = false
  #   object.setting          # => false
  #   Base.setting            # => true
  def my_class_attribute(*attrs)
    instance_reader    = true
    instance_writer    = true

    attrs.each do |name|
      singleton_class.silence_redefinition_of_method(name)
      define_singleton_method(name) { nil }

      ivar = "@#{name}".to_sym

      singleton_class.silence_redefinition_of_method("#{name}=")
      define_singleton_method("#{name}=") do |val|
        singleton_class.class_eval do
          redefine_method(name) { val }
        end

        if singleton_class?
          class_eval do
            redefine_method(name) do
              if instance_variable_defined? ivar
                instance_variable_get ivar
              else
                singleton_class.send name
              end
            end
          end
        end
        val
      end

      if instance_reader
        redefine_method(name) do
          if instance_variable_defined?(ivar)
            instance_variable_get ivar
          else
            self.class.public_send name
          end
        end
      end

      if instance_writer
        redefine_method("#{name}=") do |val|
          instance_variable_set ivar, val
        end
      end
    end
  end
end
