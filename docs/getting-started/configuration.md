---
title: Advanced setup
---

Want to make Hackatime work better for you? Here are some extra things you can set up.

## Connect your GitHub projects

Link your coding projects to GitHub so they show up better on leaderboards:

1. First, authenticate with GitHub by going to [Projects](https://hackatime.hackclub.com/my/projects) and clicking "Sign in with GitHub"
2. This will automatically link your GitHub projects to your coding activity
3. If you need to override a project link, go to [Projects](https://hackatime.hackclub.com/my/projects) → click the pencil emoji (✏️) next to a project → set the GitHub URL

This helps because:

- Your projects show up with links on leaderboards
- Other people can see what you're building
- Your GitHub activity connects to your coding time

## Set your time zone

Make sure your daily stats are right by setting your time zone:

1. Go to [Settings](https://hackatime.hackclub.com/my/settings)
2. Pick your time zone from the list
3. Save it

## What we track (and what we don't)

### What Hackatime sees

Hackatime only tracks:

- **File names** (like `main.py` or `index.html`)
- **What language you're coding in** (like Python or JavaScript)
- **What editor you use** (like VS Code or Vim)
- **How long you code**

### What Hackatime never sees

Hackatime **never** tracks:

- What you type in your code
- Your passwords
- Screenshots of your screen
- Anything you type on your keyboard

## Hide files you don't want tracked

You can tell WakaTime to ignore certain files. Make a file called `.wakatime-project` in your project folder:

```ini
[settings]
exclude =
    /node_modules/
    /vendor/
    *.log
    /temp/
```

This will ignore:

- `node_modules` and `vendor` folders
- Any `.log` files
- The `temp` folder

## Only track certain projects

If you only want to track projects that have a `.wakatime-project` file:

```ini
[settings]
include_only_with_project_file = true
```

## Need help?

Having trouble with setup? Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-help channel)!
