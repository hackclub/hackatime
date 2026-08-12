---
title: Plugin settings
---

WakaTime-compatible editor plugins normally share the configuration file at `~/.wakatime.cfg` (`%USERPROFILE%\\.wakatime.cfg` on Windows). Hackatime's [setup flow](https://hackatime.hackclub.com/setup) creates the essential values:

```ini title="~/.wakatime.cfg"
[settings]
api_url = https://hackatime.hackclub.com/api/hackatime/v1
api_key = YOUR_API_KEY
heartbeat_rate_limit_seconds = 30
```

Keep the API key private. It identifies your account when plugins submit coding activity.

## Track only selected projects

To disable tracking everywhere except folders containing a `.wakatime-project` file, add:

```ini title="~/.wakatime.cfg"
[settings]
include_only_with_project_file = true
```

Then create `.wakatime-project` in each project you want to track. The file can be empty, or its first line can set the project name.

## Add project-specific settings

Create a `.wakatime` file in a project root to override global plugin settings for that project:

```ini title=".wakatime"
[settings]
exclude =
    /build/
    /generated/
```

Project settings replace the corresponding global setting. Repeat any global exclusions you still need in that project.

## Diagnose plugin problems

Set `debug = true` temporarily under `[settings]`, reproduce the problem and inspect your editor's WakaTime output or the CLI log under `~/.wakatime/`. Remove debug mode afterwards to avoid noisy logs.

If configuration changes are not picked up, restart the editor. For a guided connectivity check, rerun the [Hackatime setup flow](https://hackatime.hackclub.com/setup).
