# Example of declaring D-Bus properties
class Note < DBus::Object
  dbus_interface "org.example.Note" do
    # A read-write property "Title",
    # with `title` and `title=` accessing @title.
    dbus_attr_accessor :title, Type::STRING

    # A read-only property "Author"
    # (type specified via DBus signature)
    # with `author` reading `@author`
    dbus_attr_reader :author, "s"

    # A read-only property `Clock`
    def clock
      Time.now.to_s
    end
    dbus_reader :clock, "s"

    # Name mapping: `CreationTime`
    def creation_time
      "..."
    end
    dbus_reader :creation_time, "s"

    dbus_attr_accessor :book_volume, Type::UINT32, dbus_name: "Volume"
  end

  dbus_interface "org.example.Audio" do
    dbus_attr_accessor :speaker_volume, Type::BYTE, dbus_name: "Volume"
  end
end
