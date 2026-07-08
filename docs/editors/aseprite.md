# How to Track Time in Aseprite

![Aseprite](/images/editor-icons/aseprite-128.png)

Let's set up Aseprite to count how much time you spend making art!

## Step 1: Make a Hackatime Account

Go to **[Hackatime](https://hackatime.hackclub.com)** and make an account. Then log in.

## Step 2: Get Your Settings Ready

Click this link to the **[setup page](https://hackatime.hackclub.com/setup)**. It will set up your account so it works with Aseprite.

## Step 3: Add the Plugin to Aseprite

We will be using a community plugin to connect Aseprite to your hackatime. Thanks to the creator: **[espcaa](https://github.com/espcaa)** who created this plugin to work with Hackatime. Here are the instructions:

1. Go to this GitHub page: **[Wakatime-Aseprite](https://github.com/espcaa/wakatime-aseprite)**
2. Download the latest release from the **releases page**
3. Open Aseprite
4. Open your settings menu (`Ctrl + K` on Windows/Linux or `⌘ + ,` on macOS or **Edit > Preferences**)
5. Go to **Extensions** & add an extension with the file you just downloaded

After installing, you will need to grab your Hackatime API key and manually add it to your global configuration file:

1. Open your global `.wakatime.cfg` file located in your user home directory.
2. Structure the file with the custom Hackatime endpoint and your API key (grab your key from https://hackatime.hackclub.com/my/settings):

   ```ini
   [settings]
   api_url = https://hackatime.hackclub.com/api
   api_key = YOUR_HACKATIME_API_KEY
   ```

### Naming Your Projects
To ensure your canvas displays correctly on the Hackatime dashboard: 
* Go to **Home > ☰ > Set Project Name** 
* You'll need to do this each time you start a project for it to track correctly on Hackatime.


## If Something Goes Wrong

**Can't see your time?** Go back to the [setup page](https://hackatime.hackclub.com/setup) and try again.

**Plugin not working?** Make sure your `.wakatime.cfg` file has the correct API key and home directory path

**Still having trouble?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) - look for the #hackatime-help channel.

## What Happens Next

Start drawing! Your time will show up on your [Hackatime page](https://hackatime.hackclub.com) in a few minutes.


**Special thanks to [espcaa](https://github.com/espcaa) for creating the plugin for use with Hackatime.**
