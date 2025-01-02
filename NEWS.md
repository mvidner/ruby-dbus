# Ruby D-Bus NEWS

## Unreleased

## Ruby D-Bus 0.24.0 - 2025-01-02

Bug fixes:
 * Adapted for Ruby 3.4, which uses a single quote instead of a backtick
   in exceptions ([#145][], by Mamoru TASAKA).

[#145]: https://github.com/mvidner/ruby-dbus/pull/145

## Ruby D-Bus 0.23.1 - 2023-10-03

API:
 * Add DBus::Object.dbus_reader_attr_accessor to declare a common use case
   with a single call ([#140][]).
 * BusConnection#request_name defaults to the simple use case: single owner
   without queuing, failing fast; documented the complex use cases.

[#140]: https://github.com/mvidner/ruby-dbus/pull/140

## Ruby D-Bus 0.23.0.beta2 - 2023-06-23

License:
 * clarified to be LGPL-2.1-or-later

API:
 * DBus::Object#object_server replaces @service (which still works) and the short-lived
   @connection
 * ObjectServer#export will raise if the path is already taken by an object
 * ObjectServer#unexport now also accepts an object path
 * Connection#object_server can export objects even without requesting any
   service name ([#49][], in beta1 already).
 * Add PeerConnection for connections without a bus, useful for PulseAudio.
   Fix listening for signals there ([#44][]).
 * Moved from Connection to BusConnection: #unique_name, #proxy, #service.
   Call send_hello in BusConnection#initialize already.

Bug fixes:
 * Fixed a refactoring crasher bug in ProxyService#introspect (oops).
 * Fix crash on #unexport of /child_of_root or even /

[#44]: https://github.com/mvidner/ruby-dbus/issues/44
[#49]: https://github.com/mvidner/ruby-dbus/issues/49

## Ruby D-Bus 0.23.0.beta1 - 2023-06-05

Bug fixes:
 * A service can now have more than one name ([#69][]).
   Connection#request_service is deprecated in favor of Connection#object_server
   and BusConnection#request_name

[#69]: https://github.com/mvidner/ruby-dbus/issues/69

API:
 * Remove Service, splitting it into ProxyService and ObjectServer
 * Split off BusConnection from Connection
 * DBus::Object @service replaced by @connection

## Ruby D-Bus 0.22.1 - 2023-05-17

Bug fixes:
 * Fix OBS building by disabling IPv6 tests, [#134][].

[#134]: https://github.com/mvidner/ruby-dbus/pull/134

## Ruby D-Bus 0.22.0 - 2023-05-08

Features:
 * Enable using nokogiri without rexml (by Dominik Andreas Schorpp, [#132][])

Bug fixes:
 * Respect DBUS_SYSTEM_BUS_ADDRESS environment variable.

Other:
 * For NameRequestError, mention who is the other owner.
 * Session bus autolaunch still does not work, but: don't try launchd except
   on macOS, and improve the error message.
 * examples/gdbus split off to its own repository,
   https://github.com/mvidner/dbus-gui-gtk

[#132]: https://github.com/mvidner/ruby-dbus/pull/132

## Ruby D-Bus 0.21.0 - 2023-04-08

Features:
 * Respect env RUBY_DBUS_ENDIANNESS=B (or =l) for outgoing messages.

Bug fixes:
 * Reduce socket buffer allocations ([#129][]).
 * Message#marshall speedup: don't marshall the body twice.

[#129]: https://github.com/mvidner/ruby-dbus/pull/129

## Ruby D-Bus 0.20.0 - 2023-03-21

Features:
 * For EXTERNAL authentication, try also without the user id, to work with
   containers ([#126][]).
 * Thread safety, as long as the non-main threads only send signals.

[#126]: https://github.com/mvidner/ruby-dbus/issues/126

## Ruby D-Bus 0.19.0 - 2023-01-18

API:
 * Added a ObjectManager mix-in to implement the service-side
   [ObjectManager][objmgr] interface.

Bug fixes:
 * dbus_attr_accessor and friends validate the signature ([#120][]).
 * Declare the Introspectable interface in exported objects([#99][]).
 * Do reply with an error when calling a nonexisting object
   with an existing path prefix([#121][]).

[#120]: https://github.com/mvidner/ruby-dbus/issues/120
[#99]: https://github.com/mvidner/ruby-dbus/issues/99
[#121]: https://github.com/mvidner/ruby-dbus/issues/121
[objmgr]: https://dbus.freedesktop.org/doc/dbus-specification.html#standard-interfaces-objectmanager

## Ruby D-Bus 0.18.1 - 2022-07-13

No changes since 0.18.0.beta8.
Repeating the most important changes since 0.17.0:

API:
 * Introduced DBus::Data classes, use them in Properties.Get,
   Properties.GetAll to return correct types as declared ([#97][]).
 * Introduced Object#dbus_properties_changed to send correctly typed property
   values ([#115][]). Avoid calling PropertiesChanged directly as it will
   guess the types.
 * Service side `emits_changed_signal` to control emission of
   PropertiesChanged: can be assigned within `dbus_interface` or as an option
   when declaring properties ([#117][]).
 * DBus.variant(type, value) is deprecated in favor of
   Data::Variant.new(value, member_type:)
 * Added type factories
   * Type::Array[type]
   * Type::Hash[key_type, value_type]
   * Type::Struct[type1, type2...]

Bug fixes:
 * Fix Object.dbus_reader to work with attr_accessor and automatically produce
   dbus_properties_changed for properties that are read-write at
   implementation side and read-only at D-Bus side ([#96][])
 * Service-side properties: Fix Properties.Get, Properties.GetAll
   to use the specific property signature, not the generic
   Variant ([#97][], [#105][], [#109][]).
 * Client-side properties: When calling Properties.Set in
   ProxyObjectInterface#[]=, use the correct type ([#108][]).
 * Added thorough tests (`spec/data/marshall.yaml`) to detect nearly all
   invalid data at unmarshalling time.

Requirements:
 * Require Ruby 2.4, because of RuboCop 1.0.

## Ruby D-Bus 0.18.0.beta8 - 2022-06-21

Bug fixes:
 * Introduced Object#dbus_properties_changed to send correctly typed property
   values ([#115][]). Avoid calling PropertiesChanged directly as it will
   guess the types.
 * Fix Object.dbus_reader to work with attr_accessor and automatically produce
   dbus_properties_changed for properties that are read-write at
   implementation side and read-only at D-Bus side ([#96][])

[#96]: https://github.com/mvidner/ruby-dbus/issues/96

API:
 * Service side `emits_changed_signal` to control emission of
   PropertiesChanged: can be assigned within `dbus_interface` or as an option
   when declaring properties ([#117][]).

[#115]: https://github.com/mvidner/ruby-dbus/issues/115
[#117]: https://github.com/mvidner/ruby-dbus/pull/117

## Ruby D-Bus 0.18.0.beta7 - 2022-05-29

API:
 * DBus.variant(type, value) is deprecated in favor of
   Data::Variant.new(value, member_type:)

Bug fixes:
 * Client-side properties: When calling Properties.Set in
   ProxyObjectInterface#[]=, use the correct type ([#108][]).

[#108]: https://github.com/mvidner/ruby-dbus/issues/108

## Ruby D-Bus 0.18.0.beta6 - 2022-05-25

API:
 * Data::Base#value returns plain Ruby types;
   Data::Container#exact_value contains Data::Base ([#114][]).
 * Data::Base#initialize and .from_typed allow plain or exact values, validate
   argument types.
 * Implement #== (converting) and #eql? (strict) for Data::Base and DBus::Type.

[#114]: https://github.com/mvidner/ruby-dbus/pull/114

## Ruby D-Bus 0.18.0.beta5 - 2022-04-27

API:
 * DBus::Type instances are frozen.
 * Data::Container classes (Array, Struct, DictEntry, but not Variant)
   constructors (#initialize, .from_items, .from_typed) changed to have
   a *type* argument instead of *member_type* or *member_types*.
 * Added type factories
   * Type::Array[type]
   * Type::Hash[key_type, value_type]
   * Type::Struct[type1, type2...]

Bug fixes:
 * Properties containing Variants would return them doubly wrapped ([#111][]).

[#111]: https://github.com/mvidner/ruby-dbus/pull/111

## Ruby D-Bus 0.18.0.beta4 - 2022-04-21

Bug fixes:
 * Service-side properties: Fix Properties.Get, Properties.GetAll for
   properties that contain arrays, on other than outermost level ([#109][]).
 * Sending variants: fixed make_variant to correctly guess the signature
   for UInt64 and number-keyed hashes/dictionaries.

[#109]: https://github.com/mvidner/ruby-dbus/pull/109

## Ruby D-Bus 0.18.0.beta3 - 2022-04-10

Bug fixes:
 * Service-side properties: Fix Properties.Get, Properties.GetAll for Array,
   Dict, and Variant types ([#105][]).

[#105]: https://github.com/mvidner/ruby-dbus/pull/105

## Ruby D-Bus 0.18.0.beta2 - 2022-04-04

API:
 * Renamed the DBus::Type::Type class to DBus::Type
   (which was previously a module).
 * Introduced DBus::Data classes, use them in Properties.Get,
   Properties.GetAll to return correct types as declared (still [#97][]).

Bug fixes:
 * Signature validation: Ensure DBus.type produces a valid Type
 * Detect more malformed messages: non-NUL padding bytes, variants with
   multiple or no value.
 * Added thorough tests (`spec/data/marshall.yaml`) to detect nearly all
   invalid data at unmarshalling time.

## Ruby D-Bus 0.18.0.beta1 - 2022-02-24

API:
 * D-Bus structs have been passed as Ruby arrays. Now these arrays are frozen.
 * Ruby structs can be used as D-Bus structs.

Bug fixes:
 * Returning the value for o.fd.DBus.Properties.Get, use the specific property
   signature, not the generic Variant ([#97][]).

Requirements:
 * Require Ruby 2.4, because of RuboCop 1.0.

[#97]: https://github.com/mvidner/ruby-dbus/issues/97

## Ruby D-Bus 0.17.0 - 2022-02-11

API:
 * Export properties with `dbus_attr_accessor`, `dbus_reader` etc. ([#86][]).

Bug fixes:
 * Depend on rexml which is separate since Ruby 3.0 ([#87][],
   by Toshiaki Asai).
   Nokogiri is faster but bigger so it remains optional.
 * Fix connection in case ~/.dbus-keyrings has multiple cookies, showing
   as "Oops: undefined method `zero?' for nil:NilClass".
 * Add the missing name to the root introspection node.

[#86]: https://github.com/mvidner/ruby-dbus/pull/86
[#87]: https://github.com/mvidner/ruby-dbus/pull/87

## Ruby D-Bus 0.16.0 - 2019-10-15

API:
 * An invalid service name or an invalid object path will raise
   instead of being sent to the bus. The bus would then drop the connection,
   producing EOFError here ([#80][]).

[#80]: https://github.com/mvidner/ruby-dbus/issues/80

## Ruby D-Bus 0.15.0 - 2018-04-30

API:
 * Accessing an unknown interface will raise instead of returning nil ([#74][]).

Bug fixes:
 * Fixed a conflict with activesupport 5.2 ([#71])

[#71]: https://github.com/mvidner/ruby-dbus/issues/71
[#74]: https://github.com/mvidner/ruby-dbus/pull/74

## Ruby D-Bus 0.14.1 - 2018-01-05

Bug fixes:
 * Allow registering signal handlers while a signal is being handled
   ([#70][], Jan Biniok).

[#70]: https://github.com/mvidner/ruby-dbus/pull/70

## Ruby D-Bus 0.14.0 - 2017-10-13

Bug fixes:
 * Sending 16-bit signed integers ("n") did not work at all ([#68][]).

Requirements:
 * Stopped supporting ruby 2.0.0, because of Nokogiri.

[#68]: https://github.com/mvidner/ruby-dbus/issues/68

## Ruby D-Bus 0.13.0 - 2016-09-21

Bug fixes:
 * It is no longer required to explicitly call ProxyObject#introspect,
   it will be done automatically once ([#28][]).

Requirements:
 * Introduced RuboCop to keep a consistent coding style.
 * Replaced Gemfile.ci with a regular Gemfile.

[#28]: http://github.com/mvidner/ruby-dbus/issue/28

## Ruby D-Bus 0.12.0 - 2016-09-12

API:
 * Added proxy objects whose methods return single values instead of arrays
   (use Service#[] instead of Service#object; [#30][]).

Requirements:
 * Require ruby 2.0.0, stopped supporting 1.9.3.

[#30]: http://github.com/mvidner/ruby-dbus/issue/30

## Ruby D-Bus 0.11.2 - 2016-09-11

Bug fixes:
 * Fixed reading a quoted session bus address, as written by dbus-1.10.10
   ([#62][], Yasuhiro Asaka)

[#62]: https://github.com/mvidner/ruby-dbus/pull/62

## Ruby D-Bus 0.11.1 - 2016-05-12

Bug fixes:
 * Fix default path finding on FreeBSD (Greg)
 * Service#unexport fixed to really return the unexported object

Requirements:
 * made tests compatible with RSpec 3

## Ruby D-Bus 0.11.0 - 2014-02-17

API:
 * Connection: split off MessageQueue, marked other methods as private.

Requirements:
 * converted tests to RSpec, rather mechanically for now

## Ruby D-Bus 0.10.0 - 2014-01-10

Bug fixes:
 * fixed "Interfaces added with singleton_class.instance_eval aren't
   exported" ([#22][], by miaoufkirsh)

Requirements:
 * Require ruby 1.9.3, stopped supporting 1.8.7.

[#22]: https://github.com/mvidner/ruby-dbus/issue/22

## Ruby D-Bus 0.9.3 - 2014-01-02

Bug fixes:
 * re-added COPYING, NEWS, README.md to the gem ([#47][],
   by Cédric Boutillier)

Packaging:
 * use packaging_rake_tasks

[#47]: https://github.com/mvidner/ruby-dbus/issue/47

## Ruby D-Bus 0.9.2 - 2013-05-08

Features:
 * Ruby strings can be passed where byte arrays ("ay") are expected 
   ([#40][], by Jesper B. Rosenkilde)

Bug fixes:
 * Fixed accessing ModemManager properties ([#41][], reported
   by Ernest Bursa). MM introspection produces two elements
   for a single interface; merge them.

[#40]: https://github.com/mvidner/ruby-dbus/issue/40
[#41]: https://github.com/mvidner/ruby-dbus/issue/41

## Ruby D-Bus 0.9.1 - 2013-04-23

Bug fixes:
 * Prefer /etc/machine-id to /var/lib/dbus/machine-id
   when DBUS_SESSION_BUS_ADDRESS is unset ([#39][], by WU Jun).

[#39]: https://github.com/mvidner/ruby-dbus/issue/39

## Ruby D-Bus 0.9.0 - 2012-11-06

Features:
 * When calling methods, the interface can be left unspecified if unambiguous
  (Damiano Stoffie)
 * YARD documentation, Reference.md

Bug fixes:
 * Introspection attribute "direction" can be omitted
   as allowed by the specification (Noah Meyerhans).
 * ProxyObjectInterface#on_signal no longer needs the "bus" parameter
   ([#31][], by Damiano Stoffie)

[#31]: https://github.com/mvidner/ruby-dbus/issue/31

## Ruby D-Bus 0.8.0 - 2012-09-20

Features:
 * Add Anonymous authentication ([#27][], by Walter Brebels).
 * Use Nokogiri for XML parsing when available ([#24][], by Geoff Youngs).

Bug fixes:
 * Use SCM_CREDS authentication only on FreeBSD, not on OpenBSD ([#21][],
   reported by Adde Nilsson).
 * Recognize signature "h" (UNIX_FD) used eg. by Upstart ([#23][],
   by Bernd Ahlers).
 * Find the session bus also via launchd, on OS X ([#20][], reported
   by Paul Sturgess).

Other:
 * Now doing continuous integration with Travis:
     http://travis-ci.org/#!/mvidner/ruby-dbus

[#20]: https://github.com/mvidner/ruby-dbus/issue/20
[#21]: https://github.com/mvidner/ruby-dbus/issue/21
[#23]: https://github.com/mvidner/ruby-dbus/issue/23
[#24]: https://github.com/mvidner/ruby-dbus/issue/24
[#27]: https://github.com/mvidner/ruby-dbus/issue/27

## Ruby D-Bus 0.7.2 - 2012-04-05

A brown-paper-bag release.

Bug fixes:
 * Fixed "undefined local variable or method `continue'" in
   DBus::Main#run when a service becomes idle (by Ravil Bayramgalin)

## Ruby D-Bus 0.7.1 - 2012-04-04

Bug fixes:
 * Fixed calling asynchronous methods on the default interface ([#13][],
   by Eugene Korbut). 
 * Fixed Main#quit to really quit the loop (by Josef Reidinger)
 * Unbundled files from Active Support (by Bohuslav Kabrda)

[#13]: https://github.com/mvidner/ruby-dbus/issue/13

## Ruby D-Bus 0.7.0 - 2011-07-26

Features:
 * Added ASystemBus and ASessionBus, non-singletons useful in tests
   and threads.

Bug fixes:
 * Fixed handling of multibyte strings ([#8][], by Takayuki YAMAGUCHI).
 * Allow reopening of a dbus_interface declaration ([#9][], by T. YAMAGUCHI).
 * Fixed ruby-1.9.2 compatibility again ([#12][]).
 * Fixed authentication on BSD ([#11][], by Jonathan Walker)
 * Fixed exiting a nested event loop for synchronous calls
   (reported by Timo Warns).
 * Fixed introspection calls leaking reply handlers.
 * "rake test" now works, doing what was called "rake env:test"

[#8]: https://github.com/mvidner/ruby-dbus/issue/8
[#9]: https://github.com/mvidner/ruby-dbus/issue/9
[#11]: https://github.com/mvidner/ruby-dbus/issue/11
[#12]: https://github.com/mvidner/ruby-dbus/issue/12

## Ruby D-Bus 0.6.0 - 2010-12-11

Features:
 * Clients can access properties conveniently ([T#28][]).

Bug fixes:
 * Service won't crash whan handling an unknown method or interface ([T#31][]).
 * Don't send an invalid error name when it originates from a NameError.

[T#28]: https://trac.luon.net/ruby-dbus/ticket/28
[T#31]: https://trac.luon.net/ruby-dbus/ticket/31

## Ruby D-Bus 0.5.0 - 2010-11-07

Features:
 * Better binding of Ruby Exceptions to D-Bus Errors.
 * Converted the package to a Gem ([#6][]).
 * Converted the tutorial from Webgen to Markdown.

Bug fixes:
 * Don't pass file descriptors to subprocesses.
 * Fixed InterfaceElement::validate_name ([T#38][], by Herwin Weststrate).
 * Fixed a typo in InvalidDestinationName description ([T#40][]).

[#6]: https://github.com/mvidner/ruby-dbus/issue/6
[T#38]: https://trac.luon.net/ruby-dbus/ticket/38
[T#40]: https://trac.luon.net/ruby-dbus/ticket/40

## Ruby D-Bus 0.4.0 - 2010-08-20

Features:
 * TCP transport (by pangdudu)
 * Enabled test code coverage report (rcov)

Bug fixes:
 * Classes should not share all interfaces ([T#36][]/[#5][])
 * Ruby 1.9 compatibility ([T#37][], by Myra Nelson)

[#5]: https://github.com/mvidner/ruby-dbus/issue/5
[T#36]: https://trac.luon.net/ruby-dbus/ticket/36
[T#37]: https://trac.luon.net/ruby-dbus/ticket/37

## Ruby D-Bus 0.3.1 - 2010-07-22

Bug fixes:
 * Many on_signal could cause DBus.Error.LimitsExceeded [bsc#617350][]).
   Don't add a match rule that already exists, enable removing match
   rules. Now only one handler for a rule is called (but it is possible
   for one signal to match more rules). This reverts the half-fix done
   to fix [#3][]
 * Re-added InterfaceElement#add_param for compatibility.
 * Handle more ways which tell us that a bus connection has died.

[#3]: https://github.com/mvidner/ruby-dbus/issue/3
[bsc#617350]: https://bugzilla.suse.com/show_bug.cgi?id=617350

## Ruby D-Bus 0.3.0 - 2010-03-28

Bug fixes:
 
 * Fixed "undefined method `get_node' for nil:NilClass"
   on Ubuntu Karmic ([T#34][]).
 * Get the session bus address even if unset in ENV ([#4][]).
 * Improved exceptions a bit:
   UndefinedInterface, InvalidMethodName, NoMethodError, no RuntimeException

 These are by Klaus Kaempf:
 * Make the signal dispatcher call all handlers ([#3][]).
 * Run on Ruby < 1.8.7 ([#2][]).
 * Avoid needless DBus::IncompleteBufferException ([T#33][]).
 * Don't ignore DBus Errors in request_service, raise them ([T#32][]).

[#2]: https://github.com/mvidner/ruby-dbus/issue/2
[#3]: https://github.com/mvidner/ruby-dbus/issue/3
[#4]: https://github.com/mvidner/ruby-dbus/issue/4
[T#32]: https://trac.luon.net/ruby-dbus/ticket/32
[T#33]: https://trac.luon.net/ruby-dbus/ticket/33
[T#34]: https://trac.luon.net/ruby-dbus/ticket/34

Features:

 * Automatic signature inference for variants.
 * Introduced FormalParameter where a plain pair had been used.

## Ruby D-Bus 0.2.12 - 2010-01-24

Bug fixes:

 * Fixed a long-standing bug where a service activated by the bus
   would fail with "undefined method `get_node' for nil:NilClass"
   ([T#25][] and [T#29][]).

[T#25]: https://trac.luon.net/ruby-dbus/ticket/25
[T#29]: https://trac.luon.net/ruby-dbus/ticket/29


## Ruby D-Bus 0.2.11 - 2009-11-12

Features:

 * Added DBus::Service#unexport (da1l6).

Bug fixes:

 * Return org.freedesktop.DBus.Error.UnknownObject instead of crashing
   ([T#31][]).
 * Rescue exceptions in dbus_methods and reply with DBus errors instead of
   crashing (da1l6).
 * Better exception messages when sending nil, or mismatched structs.
 * Call mktemp without --tmpdir, to build on older distros.

[T#31]: https://trac.luon.net/ruby-dbus/ticket/31

## Ruby D-Bus 0.2.10 - 2009-09-10

Bug fixes:

 * DBus::Service.exists? fixed (Murat Demirten).
 * Ruby 1.9 fixes (Jedediah Smith).
 * Fixed an endless sleep in DBus::Main.run ([bsc#537401][]).
 * Added details to PacketMarshaller exceptions ([bsc#538050][]).

[bsc#537401]: https://bugzilla.suse.com/show_bug.cgi?id=537401
[bsc#538050]: https://bugzilla.suse.com/show_bug.cgi?id=538050

## Ruby D-Bus "I'm not dead" 0.2.9 - 2009-08-26

Thank you to Paul and Arnaud for starting the project. I, Martin
Vidner, am continuing with it on GitHub.

 * Fixed passing an array through a variant (no ticket).
 * Fixed marshalling "av" ([T#30][]).
 * Fixed variant alignment ([T#27][]).
 * Added DBus::Main.quit.
 * Mention the DBus interface in a NameError for an unknown method.
 * Fixed ruby-1.9 "warning: default `to_a' will be obsolete".
 * Added Rakefile and gemspec.

[T#27]: https://trac.luon.net/ruby-dbus/ticket/27
[T#30]: https://trac.luon.net/ruby-dbus/ticket/30

## Ruby D-Bus "Thanks for all the fish" 0.2.1 - 2007-12-29

More bugfixes, mostly supplied by users supplying us with patches.  Thanks!

 * Support for new types added: 
   - dict (courtesy of Drake Wilson);
   - double (courtesy of Patrick Sissons);
   - variant.
 * Improved exception raise support (courtesy of Sjoerd Simons,
   Patrick Sissons).
 * Some polish (removed debug output, solved unnecessary warnings).
 * Documentation updates, example fixes and updates.

## Ruby D-Bus "Almost live from DebConf 7" 0.2.0 - 2007-06-02

Again a bugfix release, also meant to be the public release
for exploratory purposes. New in 0.2.0:

 * Complete tutorial revamp.
 * Relicensed to the LGPL.

## Ruby D-Bus "Release Often" 0.1.1 - 2007-04-23

Bugfix release.  Fixes hardcoded string for requesting bus names,
found by Rudi Cilibrasi.

## Ruby D-Bus "Happy Birthday Paul" 0.1.0 - 2007-04-17

First release. Supports most of D-Bus' features.
