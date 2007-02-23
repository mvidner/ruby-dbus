/*
 * Copyright 2007 Arnaud Cornet.
 *
 * TODO: Add GPL legal header.
 *
 */

#include <ruby.h>
#include <dbus/dbus.h>
#include <alloca.h>

VALUE mDBus;
VALUE cDBusConnection;
VALUE eDBusException;
VALUE cDBusMessage;

void rubydbus_exception(DBusError *error)
{
	char *rubymessage;
	/* not leaking when using exception hurts the head */

	rubymessage = alloca(strlen(error->name) + strlen(": ") +
			strlen(error->message) + 1);
	strcpy(rubymessage, error->name);
	strcpy(rubymessage, ": ");
	strcpy(rubymessage, error->message);

	dbus_error_free(error);

	rb_raise(eDBusException, error->message);
}

static VALUE rubydbus_connection_new(VALUE class, VALUE address)
{
	DBusConnection *connection;
	DBusError error;
	VALUE rconnection;

	dbus_error_init(&error);

	connection = dbus_connection_open(StringValuePtr(address), &error);
	if (connection == NULL || dbus_error_is_set(&error))
		rubydbus_exception(&error);

	rconnection = Data_Wrap_Struct(cDBusConnection, 0,
			dbus_connection_unref, connection);
	rb_obj_call_init(rconnection, 0, 0);
	return rconnection;
}

static VALUE rubydbus_connection_new_private(VALUE class, VALUE address)
{
	DBusConnection *connection;
	DBusError error;
	VALUE rconnection;

	dbus_error_init(&error);
	connection = dbus_connection_open_private(StringValuePtr(address),
			&error);
	if (connection == NULL)
		rubydbus_exception(&error);

	rconnection = Data_Wrap_Struct(cDBusConnection, 0,
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
	return Data_Wrap_Struct(cDBusMessage, 0, dbus_message_unref, message);
}

static VALUE rubydbus_connection_close(VALUE self)
{
	DBusConnection *connection;

	Data_Get_Struct(self, DBusConnection, connection);
	dbus_connection_close(connection);
	return self;
}

static VALUE rubydbus_connection_send(VALUE self, VALUE msg, VALUE rserial)
{
	DBusConnection *connection;
	DBusMessage *message;
	unsigned int serial;

	serial = NUM2INT(rserial);
	Data_Get_Struct(self, DBusConnection, connection);
	Data_Get_Struct(self, DBusMessage, message);
	printf("coucou4 %d\n", serial);
	if (!dbus_connection_send(connection, message, &serial))
		rb_raise(rb_eNoMemError, "dbus_connection_send");
	printf("coucou5\n");
	return INT2NUM(serial);
}

static VALUE rubydbus_connection_flush(VALUE self)
{
	DBusConnection *connection;

	Data_Get_Struct(self, DBusConnection, connection);
	dbus_connection_flush(connection);
	return self;
}

static VALUE rubydbus_connection_request_name(VALUE self, VALUE rname,
		VALUE rflags)
{
	DBusConnection *bus;
	DBusError error;
	int ret;

	dbus_error_init(&error);
	Data_Get_Struct(self, DBusConnection, bus);

	ret = dbus_bus_request_name(bus, StringValuePtr(rname), 
			NUM2INT(rflags), &err);
	if (dbus_error_is_set(&err))
		rubydbus_exception(&error);
	return INT2NUM(ret);
}


void Init_dbus_bus(void);
void Init_dbus_message(void);

void Init_dbusglue(void)
{
	mDBus = rb_define_module("DBus");

	eDBusException = rb_define_class_under(mDBus, "Exception",
			rb_eException);

	cDBusConnection = rb_define_class_under(mDBus, "Connection",
			rb_cObject);
	rb_define_singleton_method(cDBusConnection, "new",
			rubydbus_connection_new, 1);
	/* maybe use a ruby alias */
	rb_define_singleton_method(cDBusConnection, "open",
			rubydbus_connection_new, 1);
	rb_define_singleton_method(cDBusConnection, "new_private",
			rubydbus_connection_new_private, 1);
	rb_define_singleton_method(cDBusConnection, "open_private",
			rubydbus_connection_new_private, 1);

	rb_define_method(cDBusConnection, "pop_message",
			rubydbus_connection_pop_message, 0);
	rb_define_method(cDBusConnection, "close",
			rubydbus_connection_close, 0);
	rb_define_method(cDBusConnection, "send",
			rubydbus_connection_send, 2);
	rb_define_method(cDBusConnection, "flush",
			rubydbus_connection_flush, 0);
	rb_define_method(cDBusConnection, "request_name",
			rubydbus_connection_request_name, 2);

	rb_define_const(cDBusConnection, "REQUEST_NAME_PRIMARY_OWNER",
			INT2NUM(DBUS_REQUEST_NAME_REPLY_PRIMARY_OWNER));
	rb_define_const(cDBusConnection, "REQUEST_NAME_REPLY_IN_QUEUE",
			INT2NUM(DBUS_REQUEST_NAME_REPLY_IN_QUEUE));
	rb_define_const(cDBusConnection, "REQUEST_NAME_REPLY_EXISTS",
			INT2NUM(DBUS_REQUEST_NAME_REPLY_EXISTS));
	rb_define_const(cDBusConnection, "REQUEST_NAME_REPLY_ALREADY_OWNER",
			INT2NUM(DBUS_REQUEST_NAME_REPLY_ALREADY_OWNER));

	rb_define_const(cDBusConnection, "NAME_FLAG_ALLOW_REPLACEMENT",
			INT2NUM(DBUS_NAME_FLAG_ALLOW_REPLACEMENT));
	rb_define_const(cDBusConnection, "NAME_FLAG_REPLACE_EXISTING",
			INT2NUM(DBUS_NAME_FLAG_REPLACE_EXISTING));
	rb_define_const(cDBusConnection, "NAME_FLAG_DO_NOT_QUEUE",
			INT2NUM(DBUS_NAME_FLAG_DO_NOT_QUEUE));

	Init_dbus_bus();
	Init_dbus_message();
}

