---
title: Xcode
sidebar: { icon: "/images/editor-icons/xcode-32.webp" }
---
![Xcode](/images/editor-icons/xcode-128.png)

Follow these steps to start tracking your coding time in Xcode with Hackatime.

## Step 1: Log into Hackatime

Make sure you have a [Hackatime account](https://hackatime.hackclub.com) and are logged in.

## Step 2: Run the setup script

Visit the [setup page](https://hackatime.hackclub.com/setup) to automatically configure your API key and endpoint. This ensures everything works perfectly with Hackatime.

## Step 3: Install the Xcode plugin

Run this command in your terminal to install the Hack Club xcode-hackatime plugin:

```bash
curl -fsSL https://raw.githubusercontent.com/hackclub/xcode-hackatime/main/install.sh | bash
```

This installs `xcode-hackatime`, a background agent that tracks your Xcode coding time (file, line, cursor position, and saves) using your Hackatime configuration from the setup script.

## Step 4: Grant Accessibility permission

The agent reads your cursor position through macOS Accessibility, so macOS asks you to allow it once: **System Settings -> Privacy & Security -> Accessibility -> enable `xcode-hackatime`**. An onboarding window walks you through it, and a notification confirms when tracking starts. That's it - the agent starts at login and follows Xcode automatically.

## Troubleshooting

- **Not seeing your time?** Make sure you completed the [setup page](https://hackatime.hackclub.com/setup) first
- **Something not working?** Run `~/.wakatime/xcode-hackatime doctor` - it checks every part of the tracking chain and prints a fix for anything broken
- **Previously used the WakaTime Mac app?** xcode-hackatime turns off its Xcode tracking automatically so your time is not double-counted (you'll get a notification when that happens)
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-help channel)

## Next steps

Once configured, your coding time will automatically appear on your [Hackatime dashboard](https://hackatime.hackclub.com). Happy coding!
