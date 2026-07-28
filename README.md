# Framework Fan Control for DankMaterialShell

A small DankMaterialShell plugin for monitoring and switching
[fw-fanctrl](https://github.com/TamtamHero/fw-fanctrl) strategies from
DankBar.

The plugin is intentionally only a UI wrapper. It does not edit fan curves,
replace the fw-fanctrl service, or talk to the Framework embedded controller
directly.

## Features

- Shows the effective fan strategy in horizontal and vertical DankBar layouts.
- Displays fan speed, temperature, and service state.
- Discovers strategies from the running fw-fanctrl service.
- Switches to a named strategy without invoking a shell.
- Restores fw-fanctrl's configured charging/discharging defaults with the
  **Automatic** option.
- Refreshes status every five seconds and reports command failures without
  changing the displayed selection optimistically.

## Requirements

- DankMaterialShell 1.5.0 or newer.
- A Framework Laptop supported by fw-fanctrl.
- A recent fw-fanctrl release whose `fw-fanctrl --help` advertises
  `--output-format JSON`.
- The fw-fanctrl service installed, configured, and running.

Confirm the CLI and service before installing the plugin:

```sh
fw-fanctrl --help
fw-fanctrl --output-format JSON print
fw-fanctrl --output-format JSON print list
```

## Installation

Clone the repository into the DMS plugin directory:

```sh
git clone https://github.com/clementpoiret/dms-fwfanctrl \
  ~/.config/DankMaterialShell/plugins/fwFanctrl
```

Then:

1. Open **DMS Settings → Plugins**.
2. Scan for plugins and enable **Framework Fan Control**.
3. Add `fwFanctrl` to the DankBar widget list.

For local development, symlink the repository instead and reload it after
changes:

```sh
ln -s /path/to/dms-fwfanctrl \
  ~/.config/DankMaterialShell/plugins/fwFanctrl
dms ipc call plugins reload fwFanctrl
```

## Usage

Click the DankBar pill to open the strategy selector.

- Selecting a named strategy runs `fw-fanctrl use <strategy>` and creates a
  manual override.
- Selecting **Automatic** runs `fw-fanctrl reset`, allowing fw-fanctrl to use
  its configured charging or discharging strategy again.
- The refresh button reloads both status and the available strategy list.

All machine-readable calls request fw-fanctrl's JSON output. Strategy names are
passed as individual process arguments, not interpolated into a shell command.

## Troubleshooting

### The plugin cannot be enabled

Ensure `fw-fanctrl` is available on the PATH inherited by DankMaterialShell and
that it supports JSON output:

```sh
fw-fanctrl --help
```

### The widget shows “Unavailable”

The executable was found, but the plugin could not query its service. Check the
service using your installation's service manager, then verify:

```sh
fw-fanctrl --output-format JSON print
```

### New strategies do not appear

Reload the fw-fanctrl configuration as usual, then use the refresh button in
the plugin popout.

## License

[MIT](LICENSE)
