/*
 * Copyright 2007 Arnaud Cornet.
 *
 * TODO: chose and display license ;)
 *
 */

#include <ruby.h>
#include <dbus/dbus.h>
#include <alloca.h>

static VALUE mDBUS;
static VALUE cDBUSConnection;
static VALUE eDBUSException;
static VALUE cDBUSMessage;

static void rubydbus_exception(DBusError *error)
{
	char *rubymessage;
	/* not leaking when using exception hurts the head */

	rubymessage = alloca(strlen(error->name) + strlen(": ") +
			strlen(error->message) + 1);
	strcpy(rubymessage, error->name);
	strcpy(rubymessage, ": ");
	strcpy(rubymessage, error->message);

	dbus_error_free(error);

	rb_raise(eDBUSException, error->message);
}

static VALUE rubydbus_connection_new(VALUE class, VALUE address)
{
	DBusConnection *connection;
	DBusError error;
	VALUE rinstance;

	connection = dbus_connection_open(StringValuePtr(address), &error);
	if (connection == NULL)
		rubydbus_exception(&error);

	rconnection = Data_Wrap_Struct(cDBUSConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}

static VALUE rubydbus_connection_new_private(VALUE class, VALUE address)
{
	DBusConnection *connection;
	DBusError error;
	VALUE rinstance;

	connection = dbus_connection_open_private(StringValuePtr(address),
			&error);
	if (connection == NULL)
		rubydbus_exception(&error);

	rconnection = Data_Wrap_Struct(cDBUSConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}

static VALUE rubydbus_connection_pop_message(VALUE self)
{
	DBusConnection *connection;
	DBusMessage *message;
	Data_Get_Struct(self, DBusConnection, connection);

	message = dbus_connection_pop_message(connection);
	return Data_Wrap_Struct(cDBUSMessage, 0, dbus_message_unref, message);
}

static VALUE rubydbus_connection_close(VALUE self)
{
	DBusConnection *connection;
	DBusMessage *message;

	Data_Get_Struct(self, DBusConnection, connection);
	dbus_connection_close(connection);
	return self
}

static VALUE rubydbus_message_new(VALUE class, VALUE msg_type)
{
	DBusMessage *message;
	VALUE ret;

	message = dbus_message_new(NUM2INT(msg_type));

	ret = Data_Wrap_Struct(cDBUSMessage, 0,
			dbus_message_unref, message);
	return ret;
}

void Init_dbusglue(void)
{
	mDBUS = rb_define_module("DBUS");

	eDBUSException = rb_define_class_under(mDBUS, "Exception",
			rb_eException);

	cDBUSConnection = rb_define_class_under(mDBUS, "Connection",
			rb_cObject);
	rb_define_singleton_method(cDBUSConnection, "new",
			rubydbus_connection_new, 1);
	/* maybe use a ruby alias */
	rb_define_singleton_method(cDBUSConnection, "open",
			rubydbus_connection_new, 1);
	rb_define_singleton_method(cDBUSConnection, "new_private",
			rubydbus_connection_new_private, 1);
	rb_define_singleton_method(cDBUSConnection, "open_private",
			rubydbus_connection_new_private, 1);

	rb_define_method(cDBUSConnection, "pop_message",
			rubydbus_connection_pop_message, 0);
	rb_define_method(cDBUSConnection, "close",
			rubydbus_connection_close, 0);

	cDBUSMessage = rb_define_class_under(mDBUS, "Message",
			rb_cObject);
	rb_define_const(cDBUSMessage, "TYPE_INVALID",
			INT2NUM(DBUS_MESSAGE_TYPE_INVALID));
	rb_define_const(cDBUSMessage, "TYPE_METHOD_CALL",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_CALL));
	rb_define_const(cDBUSMessage, "TYPE_METHOD_RETURN",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_RETURN));
	rb_define_const(cDBUSMessage, "TYPE_METHOD_ERROR",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_ERROR));
	rb_define_const(cDBUSMessage, "TYPE_METHOD_SIGNAL",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_SIGNAL));
	rb_define_singleton_method(cDBUSConnection, "new",
			rubydbus_message_new, 1);
}

