mybus = DBus.session_bus
service = mybus['org.freedesktop.ScreenSaver']
object = service.object '/ScreenSaver'
object.introspect
interface = object['org.freedesktop.ScreenSaver']
loop do
    interface.SimulateUserActivity
    sleep 5 * 60
end
