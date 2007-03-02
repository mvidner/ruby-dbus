require 'dbus'

# there is two y's in the struct, spec is wrong ?
testsig = "yyyyuua(yyv)"
tests = "l\1\0\1\0\0\0\0\1\0\0\0n\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\5\0\0\0Hello\0\0\0"

p DBus::PacketUnmarshaller.new(testsig, tests, DBus::LIL_END).parse

tests = "l\2\1\1\n\0\0\0\1\0\0\0=\0\0\0\6\1s\0\5\0\0\0:1.11\0\0\0\5\1u\0\1\0\0\0\10\1g\0\1s\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\5\0\0\0:1.11\0"
p DBus::PacketUnmarshaller.new(testsig, tests, DBus::LIL_END).parse

tests = "l\1\0\1\34\0\0\0\2\0\0\0\200\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\6\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\v\0\0\0RequestName\0\0\0\0\0\10\1g\0\2su\0\22\0\0\0test.signal.source\0\0\2\0\0\0"
p DBus::PacketUnmarshaller.new(testsig, tests, DBus::LIL_END).parse

tests = "l\4\1\1\n\0\0\0\2\0\0\0\215\0\0\0\1\1o\0\25\0\0\0/org/freedesktop/DBus\0\0\0\2\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\3\1s\0\f\0\0\0NameAcquired\0\0\0\0\6\1s\0\5\0\0\0:1.11\0\0\0\10\1g\0\1s\0\0\7\1s\0\24\0\0\0org.freedesktop.DBus\0\0\0\0\5\0\0\0:1.11\0"
p DBus::PacketUnmarshaller.new(testsig, tests, DBus::LIL_END).parse
