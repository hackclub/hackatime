---
title: Privacy and tracked data
---

Hackatime receives activity events, called heartbeats, from your WakaTime-compatible editor plugin. The plugin sends metadata about the active coding session, not the contents of the file.

## Metadata a heartbeat can contain

Depending on the editor and plugin, a heartbeat can include:

- the file path or other entity name
- project, branch, language and dependencies
- editor, operating system, machine and plugin information
- activity category, timestamp and line-count metadata
- AI coding metadata supported by newer WakaTime clients
- request metadata such as IP address and user agent

Hackatime does not receive screenshots, a stream of your keystrokes, password values or the contents of the file you are editing through ordinary heartbeats.

## Hide sensitive paths before sending

Privacy options belong under `[settings]` in `~/.wakatime.cfg`. They are applied by the plugin before a heartbeat reaches Hackatime.

Send paths relative to the detected project folder:

```ini title="~/.wakatime.cfg"
[settings]
hide_project_folder = true
```

Obfuscate every file name while retaining its extension:

```ini title="~/.wakatime.cfg"
[settings]
hide_file_names = true
```

You can also set `hide_file_names` to a list of path patterns, or use `hide_project_names`, `hide_branch_names` and `hide_dependencies` for the corresponding metadata.

## Exclude paths entirely

`exclude` entries are POSIX regular expressions. Matching activity is not sent:

```ini title="~/.wakatime.cfg"
[settings]
exclude =
    /node_modules/
    /vendor/
    \\.env$
    /private/
```

Use forward slashes in patterns, including on Windows. Test broad expressions carefully: excluded time cannot appear in Hackatime because the plugin never sends it.

For the complete client-side option reference, see the [WakaTime CLI configuration documentation](https://github.com/wakatime/wakatime-cli/blob/develop/USAGE.md).
