/*
 * Copyright 2007 Arnaud Cornet.
 *
 * TODO: Add GPL legal header.
 *
 */

#include <ruby.h>
#include <dbus/dbus.h>

VALUE mDBUS;
VALUE cDBUSConnection;
VALUE eDBUSException;
VALUE cDBUSMessage;
VALUE mDBUSBUS;

static VALUE rubydbus_bus_get(VALUE type)
{
	DBusConnection *connection;
	DBusError error;

	connection = dbus_bus_get(type, &error);
	if (connection == NULL || dbus_error_is_set(error))
		rubydbus_exception(&error);
	rconnection = Data_Wrap_Struct(cDBUSConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}

void Init_dbus_bus(void)
{
	mDBUSBUS = rb_define_module_under(mDBUS, "BUS");
	
	rb_define_const(mDBUSBUS, "BUS_SESSION", INT2NUM(DBUS_BUS_SESSION));
	rb_define_const(mDBUSBUS, "BUS_SYSTEM", INT2NUM(DBUS_BUS_SYSTEM));
	rb_define_const(mDBUSBUS, "BUS_STARTER", INT2NUM(DBUS_BUS_STARTER));

	rb_define_singleton_method(mDBUSBUS, "get",
			rubydbus_bus_get, 1);
}

