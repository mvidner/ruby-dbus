# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2016 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  class ApiOptions
    # https://github.com/mvidner/ruby-dbus/issues/30
    # @return [Boolean]
    #   - true: a proxy (client-side) method will return an array
    #     even for the most common case where the method is declared
    #     to have only one 'out parameter'
    #   - false: a proxy (client-side) method will return
    #     - one value for the only 'out parameter'
    #     - an array with more 'out parameters'
    attr_accessor :proxy_method_returns_array

    A0 = ApiOptions.new
    A0.proxy_method_returns_array = true
    A0.freeze

    A1 = ApiOptions.new
    A1.proxy_method_returns_array = false
    A1.freeze

    CURRENT = A1
  end
end
