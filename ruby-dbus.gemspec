spec = Gem::Specification.new do |s|
    s.name = "ruby-dbus"
    s.version = "0.2.1"
    s.author = "Ruby DBUS Team"
    s.email = "http://trac.luon.net"
    s.homepage = "http://trac.luon.net/data/ruby-dbus/"
    s.platform = Gem::Platform::RUBY
    s.summary = "Ruby module for interaction with dbus"
    s.files = ["examples/simple",
    "examples/simple/call_introspect.rb", "examples/service",
    "examples/service/call_service.rb",
    "examples/service/service_newapi.rb", "examples/gdbus",
    "examples/gdbus/gdbus.glade", "examples/gdbus/gdbus",
    "examples/gdbus/launch.sh", "examples/no-introspect",
    "examples/no-introspect/nm-test.rb",
    "examples/no-introspect/tracker-test.rb", "examples/rhythmbox",
    "examples/rhythmbox/playpause.rb", "examples/utils",
    "examples/utils/listnames.rb", "examples/utils/notify.rb",
    "lib/dbus", "lib/dbus/message.rb", "lib/dbus/auth.rb",
    "lib/dbus/marshall.rb", "lib/dbus/export.rb", "lib/dbus/type.rb",
    "lib/dbus/introspect.rb", "lib/dbus/matchrule.rb",
    "lib/dbus/bus.rb", "lib/dbus.rb"]
    s.require_path = "lib"
    s.autorequire = "dbus"
    s.has_rdoc = true
    s.extra_rdoc_files = ["ChangeLog", "COPYING", "README", "NEWS"]
end

