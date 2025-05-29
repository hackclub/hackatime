# Godot Setup Guide

![Godot](/images/editor-icons/godot-128.png)

Follow these steps to start tracking your game development in Godot with Hackatime.

## Step 1: Log into Hackatime

Make sure you have a [Hackatime account](https://hackatime.hackclub.com) and are logged in.

## Step 2: Run the Setup Script

Visit the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) to automatically configure your API key and endpoint. This ensures everything works perfectly with Hackatime.

## Step 3: Install Godot Super-Wakatime Plugin

There are two ways to install the plugin made by Bartosz, a Hack Clubber:

### Option A: Asset Library (Recommended)

1. Open Godot Engine
2. Go to the **AssetLib** tab in the project manager or editor
3. Search for "Godot Super Wakatime"
4. Click **Download** and then **Install**
5. Enable the plugin in **Project → Project Settings → Plugins**

### Option B: Manual Installation

1. Download the latest release from [Godot Super-Wakatime GitHub](https://github.com/BudzioT/Godot_Super-Wakatime)
2. Extract the `addons/godot_super-wakatime` folder to your project's `addons` directory
3. Enable the plugin in **Project → Project Settings → Plugins**

## Step 4: Configure the Plugin

1. After enabling the plugin, you'll be prompted to enter your WakaTime API key
2. The plugin will automatically use your Hackatime configuration from the setup script
3. Start working on your game - the plugin tracks both coding and scene building activities!

## Features

This Hack Club-approved plugin provides:
- **Accurate tracking** - Differentiates between script editing and scene building
- **Detailed metrics** - Counts keystrokes as coding, mouse clicks as scene work
- **Smart detection** - Tracks scene structure changes and file modifications
- **Seamless integration** - Works with your existing Hackatime setup

## Troubleshooting

- **Not seeing your time?** Make sure you completed the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) first
- **Plugin not enabled?** Check **Project → Project Settings → Plugins** and enable "Godot Super Wakatime"
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-dev channel)

## Next Steps

Once configured, your game development time will automatically appear on your [Hackatime dashboard](https://hackatime.hackclub.com). Happy game developing!

---

*Plugin created by [Bartosz (BudzioT)](https://github.com/BudzioT), a Hack Clubber, and officially approved for High Seas!*
