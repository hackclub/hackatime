# Hackatime Stuck "Initialised" - Hackatime VS Code Extension - Windows

If the Hackatime VS Code extension is stuck on "Initialising" on Windows, your antivirus or Windows Security may be quarantining the Wakatime executable.

## The fix?

Making sure that your security / antivirus software isn't quarantining hackatime!

You'll know you have this error if you see this in the bottom of your VS Code. Even after you start typing some code!

![Hackatime Initialising](https://cdn.hackclub.com/019ef629-a606-779a-84a7-a1ac963afc65/screenshot_2026-06-23_162344.png)

To double check this is the issue go to your `.wakatime` folder. (`CTRL - R`, enter `%USERPROFILE%` and it should be there)

![wakatime folder](https://cdn.hackclub.com/019ef637-f684-7773-90b3-433e0d6764c5/image.png)

If this wakatime folder doesn't contain a `.exe` you have this issue.

To fix this go to **Windows Security**:
Start -> **Windows Security**.

![Windows Security](https://cdn.hackclub.com/019ef62c-c8bc-7d28-a96f-fe1a6aef23e8/image.png)

Then go to **Virus and Threat Protection** and click on **Protection History**.

![Protection History](https://cdn.hackclub.com/019ef633-b87a-71ba-968e-73f4e326b212/image.png)

Once you're in there try to look for an application called `wakatime`, and then try to create an "Exclusion" for it, using the three dots.
