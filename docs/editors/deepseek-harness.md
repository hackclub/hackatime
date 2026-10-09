---
title: DeepSeek Harness
---

DeepSeek Harness (DSH) is an AI coding agent powered by the Atria model. You can
track the time you spend working in it with Hackatime.

## Step 1: Log into Hackatime

Make sure you have a [Hackatime account](https://hackatime.hackclub.com) and are logged in.

## Step 2: Get your API key

Visit your [API settings page](https://hackatime.hackclub.com/api) and copy your
Hackatime API key.

## Step 3: Install the plugin

DeepSeek Harness has a community plugin, [`dsh-hackatime`](https://www.npmjs.com/package/dsh-hackatime),
that sends heartbeats to Hackatime. Install it with the DeepSeek Harness CLI:

```sh
dsh plugin add dsh-hackatime
```

Then add your API key in the DeepSeek Harness settings card for the plugin, or
set it in `~/.wakatime.cfg`:

```ini
[settings]
api_key = your-hackatime-api-key
api_url = https://hackatime.hackclub.com/api/hackatime/v1
```

The plugin sends a heartbeat for each message, tool call, and file edit, so your
DeepSeek Harness sessions show up on your dashboard as `DeepSeek Harness`.

## Troubleshooting

- **Not seeing your time?** Make sure your API key is set and restart DeepSeek
  Harness after installing the plugin.
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-help channel)

## Next steps

Once configured, your coding time will automatically appear on your
[Hackatime dashboard](https://hackatime.hackclub.com). Happy coding!
