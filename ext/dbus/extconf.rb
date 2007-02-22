require 'mkmf'
require 'pkg-config'

unless PKGConfig.have_package("dbus-1", 1, 0, 0) or exit 1
  puts "No D-Bus development files found!"
  exit 1
end

create_makefile "dbus-glue"
