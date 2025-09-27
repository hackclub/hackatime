# Godot & Hackatime Setup

![Godot](/images/editor-icons/godot-128.png)

Follow these steps to start tracking your game development in Godot with Hackatime:

## 1: Log in to Hackatime

**[hackatime.hackclub.com](https://hackatime.hackclub.com)**

Sign in with your Hack Club Slack account. If you haven't created one yet, head to **[shiba.hackclub.com](https://shiba.hackclub.com)** and enter your email address to get a link to the Slack :)

## 2: Set up Hackatime

Follow the instructions on the site, then copy the command into whatever terminal program you use. (The command will be different on Windows - make sure to pick the right one!)

This will set some environment variables and tell Hackatime where to "phone home" when you're working.

**💡 Visit our [setup page](https://hackatime.hackclub.com/my/wakatime_setup) to automatically configure everything!**

## 3: Download Godot

**[godotengine.org/download](https://godotengine.org/download)**

Download the Godot binary! Make sure you get the **regular version** and not the .NET version - web exports (required for Shiba) aren't supported with .NET.

If you're on Linux and know what you're doing, make sure to check your distro's package manager for any special builds.

## 4: Create a New Godot Project

![Create New Project](/images/setup/godot-new-project.png)

If you'd like to be able to run your game in browser, choose the **Mobile** renderer. Otherwise, **Forward+** is a good option.

## 5: Install Godot Super WakaTime

### Via Asset Library (Recommended)

1. Open Godot Engine
2. Create or open a project  
3. Go to the **AssetLib** tab in the project manager or editor
4. Search for **"Godot Super Wakatime"**
5. If prompted, click **'Go Online'** to be able to search
6. Click **Download** and then **Install**

**Note:** If you can't find it, make sure that you created a project already & aren't searching from the project library page!

![Asset Library Search](/images/setup/godot-asset-search.png)

**Ignore any warnings that appear during installation.**

### Alternative: Manual Installation

1. Download the latest release from [Godot Super-Wakatime GitHub](https://github.com/BudzioT/Godot_Super-Wakatime)
2. Extract the `addons/godot_super-wakatime` folder to your project's `addons` directory

## 6: Enable Godot Super WakaTime

1. Go to **Project → Project Settings → Plugins**
2. Find **"Godot Super Wakatime"** in the list
3. **Enable** the plugin
4. You'll be prompted to enter your WakaTime API key (this should be automatically configured from step 2!)

![Enable Plugin](/images/setup/godot-enable-plugin.png)

**Important:** You need to install Godot Super WakaTime for every project (it's a Godot limitation)

## ✅ All Done!

After you're finished, make sure to check **[hackatime.hackclub.com](https://hackatime.hackclub.com)** after a little while and ensure you're logging progress!

You can also try some **[wakatime.com/plugins](https://wakatime.com/plugins)** if you'd like to log time spent editing your project in other programs.

## Features

This Hack Club-approved plugin provides:
- **Accurate tracking** - Differentiates between script editing and scene building
- **Detailed metrics** - Counts keystrokes as coding, mouse clicks as scene work
- **Smart detection** - Tracks scene structure changes and file modifications
- **Seamless integration** - Works with your existing Hackatime setup

## Troubleshooting

- **Not seeing your time?** Make sure you completed the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) first
- **Plugin not enabled?** Check **Project → Project Settings → Plugins** and enable "Godot Super Wakatime"
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-v2 channel)

---

*Plugin created by [Bartosz (BudzioT)](https://github.com/BudzioT), a Hack Clubber, and officially approved for Hack Club events!*
