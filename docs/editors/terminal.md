---
title: Terminal
sidebar: { icon: "/images/editor-icons/terminal-32.webp" }
---
![Terminal](/images/editor-icons/terminal-128.png)

Follow these steps to start tracking your coding time in Terminal with Hackatime.

## Step 1: Log into Hackatime

Make sure you have a [Hackatime account](https://hackatime.hackclub.com) and are logged in.

## Step 2: Run the setup script

Visit the [setup page](https://hackatime.hackclub.com/setup) to automatically configure your API key and endpoint. This ensures everything works perfectly with Hackatime.

## Step 3: Install Terminal plugin

Run this command in your terminal to install the Hack Club terminal-wakatime plugin:

```bash
curl -fsSL https://hack.club/terminal-wakatime.sh | bash
```

This installs `terminal-wakatime` and automatically configures it for bash, zsh, or fish shells. The plugin will use your Hackatime configuration from the setup script.

## Troubleshooting

- **Not seeing your time?** Make sure you completed the [setup page](https://hackatime.hackclub.com/setup) first
- **Plugin not working?** Try restarting Terminal after installation
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-help channel)

## Next steps

Once configured, your coding time will automatically appear on your [Hackatime dashboard](https://hackatime.hackclub.com). Happy coding!
