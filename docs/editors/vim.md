---
title: Vim
sidebar: { icon: "/images/editor-icons/vim-32.webp" }
---
![Vim](../../public/images/editor-icons/vim-128.png)

Let's set up Vim to count how much time you spend coding!

## Step 1: Make a Hackatime account

Go to [Hackatime](https://hackatime.hackclub.com) and make an account. Then log in.

## Step 2: Get your settings ready

Click this link to the [setup page](https://hackatime.hackclub.com/setup). It will set up your account so it works with Vim.

## Step 3: Add the plugin to Vim

### Easy way (with vim-plug)

1. Add this line to your `.vimrc` file:

   ```text
   Plug 'wakatime/vim-wakatime'
   ```

2. Save the file and restart Vim
3. Type `:PlugInstall` in Vim and press Enter

### Simple way (copy and paste)

Copy and paste this into your terminal:

```bash
echo "Plugin 'wakatime/vim-wakatime'" >> ~/.vimrc && vim +PluginInstall
```

That's it! The plugin will use your settings from Step 2.

## If something goes wrong

**Can't see your time?** Go back to the [setup page](https://hackatime.hackclub.com/setup) and try again.

**Plugin not working?** Close Vim and open it again.

**Don't know how to edit .vimrc?** Type `:e ~/.vimrc` in Vim to open it.

**Still having trouble?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) - look for the #hackatime-help channel.

## What happens next

Start coding! Your time will show up on your [Hackatime page](https://hackatime.hackclub.com) in a few minutes.
