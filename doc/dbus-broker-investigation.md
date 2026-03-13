# Can dbus-broker replace dbus-daemon for ruby-dbus?

## Summary

**Yes, mostly.** For normal library usage (connecting to the system or session
bus), dbus-broker is a transparent drop-in — ruby-dbus simply connects to a
socket address and doesn't care which daemon is behind it. For **testing**,
the situation is more nuanced because the test suite explicitly spawns
`dbus-daemon`.

## What is dbus-broker?

dbus-broker is a Linux-native reimplementation of the D-Bus message bus. It is
wire-compatible with dbus-daemon and is already the **default** on Fedora and
Arch Linux. Key improvements over dbus-daemon:

- **Reliability**: no silently dropped messages
- **Performance**: O(log n) lookups vs O(n) in dbus-daemon
- **Accounting**: per-user resource quotas resistant to chaining-exhaustion
- **Security**: resistant to deadlocks and DoS attacks

The main caveat: `dbus-broker-launch` (the compatibility launcher) **requires
systemd** for service activation. The broker binary itself has no hard
dependencies beyond libc.

## How ruby-dbus uses dbus-daemon

### 1. Runtime library (no direct dependency)

The library code in `lib/dbus/` never spawns or references `dbus-daemon`
directly. It connects to a bus via:

- **Session bus** (`lib/dbus/bus.rb`): reads `DBUS_SESSION_BUS_ADDRESS` env
  var, or falls back to `~/.dbus/session-bus/*` files, or macOS launchd.
- **System bus** (`lib/dbus/bus.rb`): reads `DBUS_SYSTEM_BUS_ADDRESS` env var,
  or defaults to `unix:path=/var/run/dbus/system_bus_socket`.
- **Connection** (`lib/dbus/message_queue.rb`): connects to unix sockets, TCP,
  or launchd — pure socket-level, daemon-agnostic.

**Conclusion**: If the system runs dbus-broker instead of dbus-daemon, the
library works without any changes. The bus address and wire protocol are
identical.

### 2. Test infrastructure (explicit dbus-daemon dependency)

The test suite spawns a **private session bus** to run integration tests in
isolation:

- **`spec/spec_helper.rb`** — `with_private_bus` spawns:
  ```
  dbus-daemon --nofork --config-file=spec/tools/dbus-limited-session.conf \
    --print-address=3 --print-pid=4
  ```
- **`spec/tools/dbus-launch-simple`** — shell script that does the same, used
  by `spec/tools/test_env`.
- **`spec/tools/dbus-limited-session.conf`** — XML config file for the test
  bus (session type, custom limits, multiple listen addresses including TCP).

Both launchers wait for the daemon to write its address and PID to temp files,
then set `DBUS_SESSION_BUS_ADDRESS` for the tests.

### 3. CI

`.travis.yml` installs the `dbus` apt package. GitHub Actions
(`.github/workflows/ruby.yml`) relies on the system-installed dbus.

## Can dbus-broker replace dbus-daemon here?

### For users of the library: YES, transparently

No changes needed. If the system session/system bus is provided by dbus-broker,
ruby-dbus connects to it exactly the same way.

### For the test suite: NOT a drop-in replacement

The test suite invokes `dbus-daemon` directly with `--nofork`,
`--config-file`, `--print-address`, and `--print-pid` flags. dbus-broker's
`dbus-broker-launch` is **not** a CLI-compatible replacement for
`dbus-daemon` — it has a different command-line interface and requires systemd
for service activation.

To support running tests against dbus-broker, we would need to either:

1. **Keep using dbus-daemon for tests** (simplest, it remains available even on
   dbus-broker systems since dbus-broker doesn't remove dbus-daemon).
2. **Use `dbus-run-session`** instead of invoking dbus-daemon directly.
   `dbus-run-session` is a small wrapper (from the dbus package) that starts a
   private session bus and runs a command within it. It works with whichever
   daemon is installed and is simpler than our custom launcher. This would be
   the cleanest approach.
3. **Abstract the daemon launch** so tests can use either dbus-daemon or
   dbus-broker-launch, selected by an env var. This is more complex and
   probably not worth it.

### Recommendation

- The **library itself** needs no changes for dbus-broker compatibility.
- For **testing**, consider migrating from the hand-rolled `dbus-launch-simple`
  / `with_private_bus` to `dbus-run-session` which is daemon-agnostic. Even
  without this change, tests will continue to work since dbus-daemon remains
  installable alongside dbus-broker on all major distributions.

## References

- [dbus-broker wiki](https://github.com/bus1/dbus-broker/wiki)
- [Fedora: Make dbus-broker the default](https://fedoraproject.org/wiki/Changes/DbusBrokerAsTheDefaultDbusImplementation)
- [Arch Linux RFC 0025](https://rfc.archlinux.page/0025-dbus-broker-default/)
- [Arch Linux D-Bus wiki](https://wiki.archlinux.org/title/D-Bus)
- [LWN: The D-Bus Broker project](https://lwn.net/Articles/731755/)
