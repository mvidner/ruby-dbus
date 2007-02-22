/*
 * Copyright 2007 Arnaud Cornet.
 *
 * TODO: chose and display license ;)
 *
 */

#include <ruby.h>
#include <dbus/dbus.h>

static VALUE mDBUS;
static VALUE cDBUSConnection;
static VALUE eDBUSException;

void rubydbus_exception(DBusError *error)
{
	/* maybe extract more info */
	rb_raise(eDBUSException, error->message);
}

static VALUE rubydbus_connection_new(VALUE class, VALUE address)
{
	DBusConnection *connection;
	DBusError error;
        VALUE rconnection;

	connection = dbus_connection_open(StringValuePtr(address), &error);
	if (connection == NULL)
		rubydbus_exception(&error);

	rconnection = Data_Wrap_Struct(cDBUSConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}


void Init_dbusglue(void)
{
	mDBUS = rb_define_module("DBUS");

	eDBUSException = rb_define_class_under(mDBUS, "Exception",
			rb_eException);

	cDBUSConnection = rb_define_class_under(mDBUS, "Connection",
			rb_cObject);
	rb_define_singleton_method(cDBUSConnection, "new",
			rubydbus_connection_new, 0);
}

