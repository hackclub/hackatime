# Add Plugins to Your Editor

Here's how to add WakaTime plugins to your code editor so Hackatime can track your coding time.

## What You Need

Before you start, make sure you have:

- A code editor (like VS Code, PyCharm, Vim, etc.)
- A [Hackatime account](/)

## Step 1: Do the Automated Setup

**First, use the [setup page](https://hackatime.hackclub.com/my/wakatime_setup)!** It automatically sets up your API key and endpoint so everything works perfectly.

## Step 2: Add WakaTime Plugin

After doing the automated setup, install the WakaTime plugin for your editor:

### VS Code

1. Open VS Code
2. Click the Extensions button (or press Ctrl+Shift+X)
3. Type "WakaTime" in the search box
4. Click Install

### PyCharm / IntelliJ

1. Go to File → Settings (on Mac: IntelliJ IDEA → Preferences)
2. Click Plugins
3. Type "WakaTime" in the search box
4. Install and restart your app

### Vim

Copy and paste this into your terminal:

```bash
git clone https://github.com/wakatime/vim-wakatime.git ~/.vim/bundle/vim-wakatime
```

### Sublime Text

1. Press Ctrl+Shift+P (or Cmd+Shift+P on Mac)
2. Type "Install Package"
3. Type "WakaTime"
4. Install it

### Other Editors

Visit [wakatime.com/plugins](https://wakatime.com/plugins) to find plugins for 40+ other editors.

## Already Have the Plugin Installed?

If you already have a WakaTime plugin, just run the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) to switch it to Hackatime. It will automatically update your settings.

## Check If It's Working

After setup, start coding! Your time will show up on your [Hackatime dashboard](https://hackatime.hackclub.com) in a few minutes.

## Need Help?

- **Not seeing your time?** Make sure the API URL is set correctly
- **Plugin not working?** Try closing and opening your editor again
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-dev channel)
