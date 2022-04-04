# frozen_string_literal: true

# This file is part of the ruby-dbus project
# Copyright (C) 2022 Martin Vidner
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License, version 2.1 as published by the Free Software Foundation.
# See the file "COPYING" for the exact licensing terms.

module DBus
  # A message while it is being parsed: a binary string,
  # with a position cursor (*pos*), and an *endianness* tag.
  class RawMessage
    # @return [String]
    # attr_reader :bytes

    # @return [Integer] position in the byte buffer
    attr_reader :pos

    # @return [:little,:big]
    attr_reader :endianness

    # @param bytes [String]
    # @param endianness [:little,:big,nil]
    #    if not given, read the 1st byte of *bytes*
    def initialize(bytes, endianness = nil)
      @bytes = bytes
      @pos = 0
      @endianness = endianness || self.class.endianness(@bytes[0])
    end

    # Get the endiannes switch as a Symbol,
    # which will make using it slightly more efficient
    # @param tag_char [String]
    # @return [:little,:big]
    def self.endianness(tag_char)
      case tag_char
      when LIL_END
        :little
      when BIG_END
        :big
      else
        raise InvalidPacketException, "Incorrect endianness #{tag_char.inspect}"
      end
    end

    # @return [void]
    # @raise IncompleteBufferException if there are not enough bytes remaining
    def want!(size)
      raise IncompleteBufferException if @pos + size > @bytes.bytesize
    end

    # @return [String]
    # @raise IncompleteBufferException if there are not enough bytes remaining
    # TODO: stress test this with encodings. always binary?
    def read(size)
      want!(size)
      ret = @bytes.slice(@pos, size)
      @pos += size
      ret
    end

    # @return [String]
    # @api private
    def remaining_bytes
      # This returns "" if pos is just past the end of the string,
      # and nil if it is further.
      @bytes[@pos..-1]
    end

    # Align the *pos* index on a multiple of *alignment*
    # @param alignment [Integer] must be 1, 2, 4 or 8
    # @return [void]
    def align(alignment)
      case alignment
      when 1
        nil
      when 2, 4, 8
        bits = alignment - 1
        pad_size = ((@pos + bits) & ~bits) - @pos
        pad = read(pad_size)
        unless pad.bytes.all?(&:zero?)
          raise InvalidPacketException, "Alignment bytes are not NUL"
        end
      else
        raise ArgumentError, "Unsupported alignment #{alignment}"
      end
    end
  end
end
