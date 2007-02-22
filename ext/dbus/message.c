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
VALUE cDBusMessageIter;

static VALUE rubydbus_message_new(VALUE class, VALUE msg_type)
{
	DBusMessage *message;
	VALUE ret;

	message = dbus_message_new(NUM2INT(msg_type));
	ret = Data_Wrap_Struct(cDBusMessage, 0,
			dbus_message_unref, message);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_new_method_call(VALUE class, VALUE rdestination,
		VALUE rpath, VALUE rinterface, VALUE rmethod)
{
	DBusMessage *message;
	VALUE ret;

	message = dbus_message_new_method_call(StringValuePtr(rdestination),
			StringValuePtr(rpath), StringValuePtr(rinterface),
			StringValuePtr(rmethod));

	ret = Data_Wrap_Struct(cDBusMessage, 0, dbus_message_unref, message);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_new_method_return(VALUE self)
{
	DBusMessage *message, *method_return;
	VALUE ret;

	Data_Get_Struct(self, DBusMessage, message);

	method_return = dbus_message_new_method_return(message);
	ret = Data_Wrap_Struct(cDBusMessage, 0, dbus_message_unref,
			method_return);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_new_signal(VALUE class, VALUE rpath,
		VALUE rinterface, VALUE rname)
{
	DBusMessage *message;
	VALUE ret;

	message = dbus_message_new_signal(StringValuePtr(rpath),
			StringValuePtr(rinterface), StringValuePtr(rname));
	ret = Data_Wrap_Struct(cDBusMessage, 0, dbus_message_unref, message);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_new_error(VALUE self, VALUE rerror_name,
		VALUE rerror_message)
{
	DBusMessage *message;
	DBusMessage *error;
	VALUE ret;

	Data_Get_Struct(self, DBusMessage, message);

	error = dbus_message_new_error(message,
			StringValuePtr(rerror_name),
			StringValuePtr(rerror_message));
	ret = Data_Wrap_Struct(cDBusMessage, 0, dbus_message_unref, error);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_new_iter_append(VALUE self)
{
	DBusMessage *message;
	DBusMessageIter *iter;
	VALUE ret;

	Data_Get_Struct(self, DBusMessage, message);

	iter = malloc(sizeof(DBusMessageIter));
	dbus_message_iter_init_append(message, iter);
	ret = Data_Wrap_Struct(cDBusMessageIter, 0, free, iter);
	rb_obj_call_init(ret, 0, 0);
	return ret;
}

static VALUE rubydbus_message_iter_append_basic(VALUE self, VALUE value)
{
	DBusMessageIter *iter;
	char *str;

	Data_Get_Struct(self, DBusMessageIter, iter);

	/* TODO switch on value type,
	 * right now assume string */

	/* how do we not leak ? */
	str = strdup(StringValuePtr(value));
	if (!dbus_message_iter_append_basic(iter, DBUS_TYPE_STRING, &str)) {
		/* If we are out of memory, there is no chance this is ever
		 * usefull... */
		rb_raise(rb_eNoMemError, "dbus_message_iter_append_basic");
	}
	return self;
}

void Init_dbus_message(void)
{
	cDBusMessage = rb_define_class_under(mDBus, "Message",
			rb_cObject);
	rb_define_const(cDBusMessage, "TYPE_INVALID",
			INT2NUM(DBUS_MESSAGE_TYPE_INVALID));
	rb_define_const(cDBusMessage, "TYPE_METHOD_CALL",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_CALL));
	rb_define_const(cDBusMessage, "TYPE_METHOD_RETURN",
			INT2NUM(DBUS_MESSAGE_TYPE_METHOD_RETURN));
	rb_define_const(cDBusMessage, "TYPE_ERROR",
			INT2NUM(DBUS_MESSAGE_TYPE_ERROR));
	rb_define_const(cDBusMessage, "TYPE_SIGNAL",
			INT2NUM(DBUS_MESSAGE_TYPE_SIGNAL));
	rb_define_singleton_method(cDBusMessage, "new",
			rubydbus_message_new, 1);
	rb_define_singleton_method(cDBusMessage, "new_method_call",
			rubydbus_message_new_method_call, 4);
	rb_define_singleton_method(cDBusMessage, "new_signal",
			rubydbus_message_new_signal, 3);

	rb_define_method(cDBusMessage, "new_method_return",
			rubydbus_message_new_method_return, 0);
	rb_define_method(cDBusMessage, "new_error",
			rubydbus_message_new_error, 2);
	rb_define_method(cDBusMessage, "new_iter_append",
			rubydbus_message_new_iter_append, 0);

	cDBusMessageIter = rb_define_class_under(mDBus, "MessageIter",
			rb_cObject);
	rb_define_method(cDBusMessageIter, "append_basic",
			rubydbus_message_iter_append_basic, 1);
}

