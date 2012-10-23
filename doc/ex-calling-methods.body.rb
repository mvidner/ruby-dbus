mybus = DBus.session_bus
service = mybus['org.freedesktop.ScreenSaver']
object = service.object '/ScreenSaver'
object.introspect
loop do
    object.SimulateUserActivity
    sleep 5 * 60
end
