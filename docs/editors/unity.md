# How to Track Time in Unity

![Unity](/images/editor-icons/unity-128.png)

Let's set up Unity to count how much time you spend making games!

## Step 1: Make a Hackatime Account

Go to **[Hackatime](https://hackatime.hackclub.com)** and make an account. Then log in.

## Step 2: Get Your Settings Ready

Click this link to the **[setup page](https://hackatime.hackclub.com/my/wakatime_setup)**. It will set up your account so it works with Unity.

## Step 3: Add the Plugin to Unity

There are a few different Unity plugins. But most of them do not work with the Hackatime API. In light of this, **[Daniel-George](https://github.com/Daniel-Geo)** created a fork of **[Vladfaust's plugin](https://github.com/vladfaust/unity-wakatime)** to work with Hackatime. Here are the instructions:

1. Open Unity Hub and start a project
2. Go to this GitHub page: **[Unity Hackatime Plugin](https://github.com/Daniel-Geo/unity-hackatime)**
3. Copy this text:  `https://github.com/daniel-geo/unity-hackatime.git#package`
4. Open your Unity project and click on ***Window > Package Management > Package Manager***
5. Click the **plus sign** on the top-left-corner of the screen
6. Select "**Install package from git URL...**"
7. Paste the text you copied earlier
8. Click "**Install**"

After installing, you will need to grab your Hackatime API key and paste it into the Unity plugin:

1. Open your Unity project
2. Go to ***Window > Hackatime***
3. Insert your API key into the text field (grab it from the Config File on your settings page: https://hackatime.hackclub.com/my/settings)
4. Click "**Save Preferences**"
5. **You are done!**


### Hackatime should start tracking these events:

- DidReloadScripts
- EditorApplication.playModeStateChanged
- EditorApplication.contextualPropertyMenu
- EditorApplication.hierarchyWindowChanged
- EditorSceneManager.sceneSaved
- EditorSceneManager.sceneOpened
- EditorSceneManager.sceneClosing
- EditorSceneManager.newSceneCreated


## If Something Goes Wrong

**Can't see your time?** Go back to the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) and try again.

**Plugin not working?** Close Unity and open it again. Or reinstall it using a different method listed on this page: **[Unity Hackatime Plugin](https://github.com/Daniel-Geo/unity-hackatime)**

**Package Manager not working?** Make sure you're connected to the internet.

**Still having trouble?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) - look for the #hackatime-help channel.

## What Happens Next

Start making your game! Your time will show up on your [Hackatime page](https://hackatime.hackclub.com) in a few minutes.


**Special thanks to [Daniel-George](https://github.com/Daniel-Geo) for editing the original plugin for use with Hackatime.**
