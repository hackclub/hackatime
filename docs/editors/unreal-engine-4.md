# Set Up Hackatime with Unreal Engine 4.27

![Unreal Engine 4](/images/editor-icons/unrealengine4-128.png)

This guide will walk you through setting up **Hackatime** to automatically track your game development time in **Unreal Engine 4.27**. This currently only supports Windows systems.

---

## Step 1: Log In to Your Hackatime Account

First, make sure you have a **Hackatime account** and are logged in. If you don't have an account, you can create one at [hackatime.hackclub.com](https://hackatime.hackclub.com).

---

## Step 2: Download UE4 WakatimeIntegration Plugin

Visit the [GitHub page](https://github.com/ZXMushroom63/WakatimeIntegration) and download the [latest release](https://github.com/ZXMushroom63/WakatimeIntegration/releases/latest). The file name should be something like `WakatimeIntegration.zip`

## Step 3: Install UE4 WakatimeIntegration Plugin

1. First, extract `WakatimeIntegration.zip`
2. Inside should be a single folder called `WakatimeIntegration` containing a `.uplugin` file among others.
3. Copy or move this folder to your Unreal Engine 4.27's plugins folder. The default location is `C:\Program Files\Epic Games\UE_4.27\Engine\Plugins\`

## Step 4: Configure API Credentials

1. Startup the editor and load into a project
2. Open the Plugins window (`Edit->Plugins...`) and enable `WakatimeIntegration`.
3. Restart the editor when prompted
4. In editor settings (`Edit->Editor Settings...`) find the WakatimeIntegration category (should be under `Plugins` category)
5. Set the Bearer Token to the API Key found at `https://hackatime.hackclub.com/my/wakatime_setup`
6. Set the Endpoint to `https://hackatime.hackclub.com/api/hackatime/v1`
7. Set the interval to `30`.
8. You may need to manually enable the plugin for each project you wish to track.

## Troubleshooting
- **Plugin not working?**
  - First thing to try is restarting your editor to ensure the plugin loads correctly
  - If time isn't being checked, check `Output Log` in the engine and look for errors/logs from `Wakatime Integration`
    - `Failed to establish connection to Wakatime endpoint.`: Make sure the endpoint URL is correct and that your internet connection is working
    - `Heartbeat failed due to invalid API token (401)`: Make sure the token is correct, it is easy to accidentally skip characters when pasting.
    - `Heartbeat accepted with code`: Everything should be working smoothly
    - `Heartbeat failed. Code: *. Response: *`: An unknown error. Look at the logs for more information, or request help in the [Hack Club Slack](https://hackclub.slack.com).
- **Plugin/editor crashing?**
  - This plugin is built for Unreal Engine 4.27, so your editor version may be too old for the prebuilt binaries.
  - If you really need this version, you can try building the plugin from [source](https://github.com/ZXMushroom63/WakatimeIntegration)

## Building for other platforms / versions of UE4
1. Clone or download the [GitHub repo](https://github.com/ZXMushroom63/WakatimeIntegration)
2. In the editor, create a new blank C++ project with minimal settings, targetting Desktop. This can be found under the games category.
    - This may take extra platform dependent setup
3. Inside your project folder, create a `Plugins` folder.
    - `Documents\Unreal Projects\MyProject\` on Windows
4. Move `WakatimeIntegration` (github repo containing `Source` and `.uplugin`) into the new `Plugins` folder.
5. In editor, open the Plugins tab and try to enable `WakatimeIntegration`
6. You should be promped to rebuild the plugin, select 'yes' and wait for the process to complete.
7. Once the build is done, open the plugins tab, search for `WakatimeIntegration`, and select 'package'
8. Package `WakatimeIntegration` to any folder, and wait for the packaging to finish.
9. Resume with `Step 2` in `Part 3: Install UE4 WakatimeIntegration Plugin`

Once the plugin is successfully installed, your Unreal Engine 4 projects should start to appear on your [Hackatime dashboard](https://hackatime.hackclub.com)!