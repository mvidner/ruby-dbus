sysbus = DBus.system_bus
upower_s = sysbus['org.freedesktop.UPower']
upower_o = upower_s.object '/org/freedesktop/UPower'
upower_o.introspect
upower_i = upower_o['org.freedesktop.UPower']

on_battery = upower_i['OnBattery']

puts "Is the computer on battery now? #{on_battery}"
