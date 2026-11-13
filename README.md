# GlassyBattery for GL-Link

A [GL-Link](https://github.com/DecKirin/gl-link-extensions) extension for the Mac: each
router with a battery, in [GlassyBattery](https://github.com/DecKirin/AirBattery)'s menu bar,
widgets and CLI, and on your other Macs.

| What GlassyBattery shows | From |
|---|---|
| The battery | The router's level, and whether it's charging |
| The name | The router's name in GL-Link. Two with one name get a number; a name another device has gets " (GL-Link)" |
| The model | "GL-E5800", or "Mudi 7 · GL-E5800" for a router called something else |
| The icon | The model's own icon, which the extension uploads. `wifi.router.fill` where GlassyBattery can't take one |

## Install

- **In GL-Link:** Settings → This Mac → App Extensions → Browse Extensions → GlassyBattery.
- **Or by its file:** download `GlassyBattery-<version>.glext` from
  [Releases](https://github.com/DecKirin/gl-link-glassybattery/releases) and open it.

GL-Link asks first, and shows what the extension can do:

- Read your routers' names, batteries and models
- Connect to other apps on this device (127.0.0.1)
- Read `~/Library/Application Support/GlassyBattery/bridge.json`, where GlassyBattery says
  which port it listens on

Then approve GL-Link in GlassyBattery, if it asks.

## How it works

It's an app extension: a script GL-Link runs while it's open, on this Mac only. It reads what
GL-Link already knows of the routers, and needs nothing on them.

- **Connecting:** it finds GlassyBattery's BatteryBridge from `bridge.json` (falling back to
  the default ports), registers once, keeps the token in its own Keychain item, and holds one
  stream open. Quitting GL-Link, or turning the extension off or removing it, takes the
  routers out of GlassyBattery at once.
- **Freshness:** only a reading under 5 minutes old is sent, and current routers are sent
  again every 2 minutes. With GL-Link's window closed, it asks for a fresh read.
- **When GlassyBattery says no:** blocked or removed there, it stops rather than undo your
  choice. **Reset Connection**, its one action, signs in again.

`GlassyBattery.ext/main.js` is the whole of it.

## Working on it

A Mac with Xcode's command line tools, and [`just`](https://github.com/casey/just) if you
like. `gllink-ext` and the test fakes come from
[GL-Link's extension SDK](https://github.com/DecKirin/gl-link-extensions), through
`Package.swift`.

```sh
just check      # the tests, against a fake BatteryBridge; and gllink-ext check
just run        # run it here against sample routers. It really talks to GlassyBattery
just install    # open it in GL-Link on this Mac
just build      # sign and pack it: build/GlassyBattery-<version>.glext
just publish    # release it here, and write its marketplace entry
```

```
GlassyBattery.ext/
  manifest.json         what it is, and what it may reach
  main.js               the script
  icons/router.*.svg    each router model's icon, which it uploads to GlassyBattery
Tests/                  the package run in GL-Link's runtime, against a fake BatteryBridge
gllink.d.ts             the script API, for your editor (`just types` refreshes it)
```

- **The icons** are drawn from GL-Link's own router symbols, by `just ext-icons` in GL-Link's
  repository.
- **A release:** raise `version` in `manifest.json`, `just publish`, and send the entry it
  writes to the [marketplace](https://github.com/DecKirin/gl-link-extensions/blob/main/MARKETPLACE.md).
  Releases are signed with the publisher's key; GL-Link takes updates only from the same key.
