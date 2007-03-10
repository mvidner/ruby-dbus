module DBus
module Type
  INVALID = 0
  BYTE = ?y
  BOOLEAN = ?b
  INT16 = ?n
  UINT16 = ?q
  INT32 = ?i
  UINT32 = ?u
  STRUCT = ?r
  ARRAY = ?a
  VARIANT = ?v
  OBJECT_PATH = ?o
  STRING = ?s
  SIGNATURE = ?g

#INT64 120 (ASCII 'x')ASCII64-bit signed integer
#UINT64 116 (ASCII 't')ASCII64-bit unsigned integer
#DOUBLE 100 (ASCII 'd')ASCIIIEEE 754 double
#DICT_ENTRY 101 (ASCII 'e'), 123 (ASCII '{'), 125 (ASCII '}') ASCIIEntry in a dict or map (array of key-value pairs)

  TypeName = {
    INVALID => "INVALID",
    BYTE => "BYTE",
    BOOLEAN => "BOOLEAN",
    INT16 => "INT16",
    UINT16 => "UINT16",
    INT32 => "INT32",
    UINT32 => "UINT32",
    STRUCT => "STRUCT",
    ARRAY => "ARRAY",
    VARIANT => "VARIANT",
    OBJECT_PATH => "OBJECT_PATH",
    STRING => "STRING",
    SIGNATURE => "SIGNATURE",
  }

  class InvalidSigException < Exception
  end
  class SignatureException < Exception
  end

  class Type
    attr_reader :sigtype, :members
    def initialize(sigtype)
      if not TypeName.keys.member?(sigtype)
        raise SignatureException, "Unknown key in signature: #{sigtype.chr}"
      end
      @sigtype = sigtype
      @members = Array.new
    end

    def <<(a)
      raise SignatureException if not [STRUCT, ARRAY].member?(@sigtype)
      raise SignatureException if @sigtype == ARRAY and @members.size > 0
      @members << a
    end

    def child
      @members[0]
    end

    def inspect
      s = TypeName[@sigtype]
      if [STRUCT, ARRAY].member?(@sigtype)
        s += ": " + @members.inspect
      end
      s
    end
  end

  class Parser
    def initialize(signature)
      @signature = signature
      @idx = 0
    end

    def nextchar
      c = @signature[@idx]
      @idx += 1
      c
    end

    def parse_one(c)
      res = nil
      case c
      when ?a
        res = Type.new(ARRAY)
        child = parse_one(nextchar)
        res << child
      when ?(
        res = Type.new(STRUCT)
        while (c = nextchar) != ?)
          res << parse_one(c)
        end
      else
        res = Type.new(c)
      end
      res
    end

    def parse
      @idx = 0
      ret = Array.new
      while (c = nextchar)
        ret << parse_one(c)
      end
      ret
    end
  end
end
end
