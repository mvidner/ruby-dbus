/*
 * Copyright 2007 Arnaud Cornet.
 *
 * TODO: Add GPL legal header.
 *
 */

#include <ruby.h>
#include <dbus/dbus.h>

extern VALUE mDBus;
extern VALUE cDBusConnection;
extern VALUE eDBusException;
extern VALUE cDBusMessage;
VALUE mDBusBus;

void rubydbus_exception(DBusError *error);

static VALUE rubydbus_bus_get(VALUE module, VALUE type)
{
	DBusConnection *connection;
	DBusError error;
	VALUE rconnection;

	dbus_error_init(&error);

	connection = dbus_bus_get(NUM2INT(type), &error);
	if (connection == NULL || dbus_error_is_set(&error))
		rubydbus_exception(&error);
	rconnection = Data_Wrap_Struct(cDBusConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}

void Init_dbus_bus(void)
{
	mDBusBus = rb_define_module_under(mDBus, "Bus");

	rb_define_const(mDBusBus, "SESSION", INT2NUM(DBUS_BUS_SESSION));
	rb_define_const(mDBusBus, "SYSTEM", INT2NUM(DBUS_BUS_SYSTEM));
	rb_define_const(mDBusBus, "STARTER", INT2NUM(DBUS_BUS_STARTER));

	rb_define_singleton_method(mDBusBus, "get",
			rubydbus_bus_get, 1);
}

