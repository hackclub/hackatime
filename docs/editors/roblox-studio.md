# Set Up Hackatime with Roblox Studio

![Roblox Studio](/images/editor-icons/roblox-studio-128.png)

This guide will walk you through setting up **Hackatime** to automatically track your game development time in **Roblox Studio**.

---

## Step 1: Log In to Your Hackatime Account

First, make sure you have a **Hackatime account** and are logged in. If you don't have an account, you can create one at [hackatime.hackclub.com](https://hackatime.hackclub.com).

---

## Step 2: Install the Hackatime Roblox Studio Plugin

Next, you'll need to install the Hackatime plugin directly within Roblox Studio:

1.  Open **Roblox Studio**.
2.  Navigate to the **Toolbox**.
3.  In the Toolbox search bar, select **"Plugins"** from the dropdown filter.
4.  Search for **"HackaTime Roblox"**.
5.  Install the plugin published by **"ThisWhity"**.

    ![Toolbox filter showing Plugins selected](https://github.com/user-attachments/assets/65931fad-fa16-4df6-9a07-eadf1e2aaf07)
    *Filter the Toolbox by "Plugins"*

    ![Toolbox search results showing HackaTime Roblox plugin](https://github.com/user-attachments/assets/13233bf7-b876-4c29-b690-9ebbcb796488)
    *Install the "HackaTime Roblox" plugin by ThisWhity*

---

## Step 3: Configure the Plugin with Your API Key

Now, you'll connect the plugin to your Hackatime account using your unique API key:

1.  Get your API key by visiting [hackatime.hackclub.com/my/wakatime_setup](https://hackatime.hackclub.com/my/wakatime_setup). It will look something like this: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.

    ![Screenshot showing API Key on Hackatime website](https://github.com/user-attachments/assets/635cab06-36cb-4351-819b-62403b6c6885)
    *Your API key from the Hackatime website*

2.  In Roblox Studio, open the **Hackatime plugin**. You'll usually find it under the "Plugins" tab in the Ribbon bar.

    ![Screenshot showing the Hackatime plugin tab with API key input](https://github.com/user-attachments/assets/c241dbe2-6f9a-44bf-adb9-f0b4780227db)
    *Open the Plugin*

4.  Paste your API key into the API key box. And hit "Save API Key"

---

## Troubleshooting

### ERR\_NETWORK: Plugin Cannot Connect to Hackatime

If you see an **ERR\_NETWORK** message, it means the plugin can't connect to Hackatime. This is likely due to you not allowing HTTP request from the plugin:

1.  Open the "Manage Plugins".
2.  Hit the edit icon.
3.  Ensure that **"hackatime.hackclub.com"** is enabled.

    ![Screenshot showing Game Settings with Security tab open and Allow HTTP Requests highlighted](https://github.com/user-attachments/assets/c3533d87-2b06-4ba8-a1c5-7416332578e9)
    *Open Plugin Managment*

    ![Screenshot showing Allow HTTP Requests enabled](https://github.com/user-attachments/assets/86bea3e2-dbbe-496f-acd4-f5963c208767)
    *Allow HTTP requests*

### Still Stuck?

If you're still experiencing issues, don't hesitate to ask for help in the **#hackatime-help channel** on the [Hack Club Slack](https://hackclub.slack.com).

---

## What's Next?

Once the plugin is successfully configured, your Roblox Studio activity time will automatically start appearing on your [Hackatime dashboard](https://hackatime.hackclub.com).

Happy game developing!
