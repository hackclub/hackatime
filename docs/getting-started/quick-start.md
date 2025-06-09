# Hackatime Quick Start Guide - Free WakaTime Alternative

Get up and running with Hackatime in under 5 minutes! Start tracking your coding time across 40+ editors with our free, open source WakaTime alternative.

## What is Hackatime?

**Hackatime** is a **free and open source** alternative to WakaTime that automatically tracks your coding time across all your favorite editors and IDEs. It works with **every existing WakaTime editor plugin** by simply configuring your `~/.wakatime.cfg` file to point to Hackatime's servers instead of WakaTime's.

## Step 1: Create Your Account

Visit [hackatime.hackclub.com](https://hackatime.hackclub.com) and sign up using:

- Your Hack Club Slack account (recommended)
- Email address

## Step 2: Run Automated Setup

🚀 **Visit the [Hackatime Setup Page](https://hackatime.hackclub.com/my/wakatime_setup)** - this will:

1. Auto-detect your operating system
2. Provide a copy-paste command that configures everything
3. Create your `~/.wakatime.cfg` file pointing to Hackatime
4. Send a test heartbeat to verify setup
5. Show you when it's working!

The setup page handles all configuration automatically - no manual editing required!

## Step 3: Install WakaTime Plugin

Hackatime works with **any WakaTime plugin**. Install for your editor:

### Popular Editors

- **VS Code**: Search "WakaTime" in Extensions marketplace
- **IntelliJ/PyCharm**: Settings → Plugins → Install "WakaTime"
- **Vim/Neovim**: Install `vim-wakatime` plugin
- **Sublime Text**: Install via Package Control
- **Atom**: Install `wakatime` package

### All Other Editors

Visit [wakatime.com/plugins](https://wakatime.com/plugins) for 40+ supported editors.

## Step 4: Configure Plugin to Use Hackatime

**If you used the setup page**: Your `~/.wakatime.cfg` is already configured! The WakaTime plugin will automatically use Hackatime.

**Manual configuration**: Edit `~/.wakatime.cfg`:

```ini
[settings]
api_url = https://hackatime.hackclub.com/api/hackatime/v1
api_key = YOUR_API_KEY_HERE
heartbeat_rate_limit_seconds = 30
```

## Step 5: Start Coding!

That's it! Open your editor and start coding. Your time will be automatically tracked and appear on your [Hackatime dashboard](https://hackatime.hackclub.com).

## Verification

Check that it's working:

1. Code for a few minutes in your editor
2. Visit your [dashboard](https://hackatime.hackclub.com)
3. You should see your coding activity appear

## Features You Get

- ⏱️ **Automatic time tracking** - no manual timers
- 📊 **Language & project insights** - see what you code most
- 🏆 **Leaderboards** - compare with other Hack Club members
- 🔒 **Privacy-first** - only metadata tracked, never your actual code
- 🆓 **Completely free** - no premium features or paywalls

## Troubleshooting

**Not seeing activity?**

1. Re-run the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) to verify configuration
2. Check that your WakaTime plugin is enabled in your editor
3. Make sure you're actively coding (not just viewing files)

**Need help?**

- Visit the [Hackatime Setup Page](https://hackatime.hackclub.com/my/wakatime_setup) for guided troubleshooting
- Join [Hack Club Slack](https://hackclub.slack.com) (#hackatime-dev channel)
- [Create an issue](https://github.com/hackclub/hackatime/issues) on GitHub

**Migrating from WakaTime?**
Just run the automated setup script on the [Hackatime Setup Page](https://hackatime.hackclub.com/my/wakatime_setup) - it will automatically update your `~/.wakatime.cfg` file and all your existing plugins will work immediately!

---

## Frequently Asked Questions

**Is Hackatime really free?** Yes! Hackatime is completely free with no premium features or paywalls. It's [open source](https://github.com/hackclub/hackatime) and maintained by Hack Club.

**Which editors work with Hackatime?** All [70+ editors](../#supported-editors) that support WakaTime work with Hackatime, including [VS Code](../editors/vs-code), [IntelliJ IDEA](../editors/intellij-idea), [Sublime Text](../editors/sublime-text), [Vim](../editors/vim), [Neovim](../editors/neovim), [PyCharm](../editors/pycharm), and many more.

**How is Hackatime different from WakaTime?** Hackatime is free, open source, privacy-focused, and includes unique features like leaderboards for Hack Club members.

**Can I import my existing WakaTime data?** Currently, data import is not supported, but you can start fresh with Hackatime while keeping your WakaTime account.

**Is my code data secure?** Hackatime only tracks metadata (file names, languages, project names) - never your actual code content. All data is encrypted in transit.
