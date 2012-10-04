sysbus = DBus.system_bus
login_s = sysbus['org.freedesktop.login1'] # part of systemd
login_o = login_s.object '/org/freedesktop/login1'
login_o.introspect
login_o.default_iface = 'org.freedesktop.login1.Manager'

# to trigger this signal, login on the Linux console
login_o.on_signal("SessionNew") do |name, opath|
  puts "New session: #{name}"

  session_o = login_s.object(opath)
  session_o.introspect
  session_i = session_o['org.freedesktop.login1.Session']
  uid, user_opath = session_i['User']
  puts "Its UID: #{uid}"
end

main = DBus::Main.new
main << sysbus
main.run
