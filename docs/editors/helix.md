# Helix & Hackatime Setup

![Helix](/images/editor-icons/helix-128.png)

Follow these steps to start tracking your coding in Helix with Hackatime:

## 1: Log in to Hackatime

**[hackatime.hackclub.com](https://hackatime.hackclub.com)**

Sign in with your Hackatime account (or create one if you don't have one yet)!

## 2: Set up Hackatime

Follow the instructions on the site, then copy the command into whatever terminal program you use. (The command will be different on Windows - make sure to pick the right one!)

This will set some environment variables and tell Hackatime where to "phone home" when you're working.

**💡 Visit our [setup page](https://hackatime.hackclub.com/my/wakatime_setup) to automatically configure everything!**

## 3: Install Helix

**[docs.helix-editor.com](https://docs.helix-editor.com/install.html)**

Download the Helix binary, or if you know what you're doing, use your distro's package manager for any special builds!

## 4: Install `wakatime-cli`

**[github.com/wakatime/wakatime-cli](https://github.com/wakatime/wakatime-cli/releases/latest)**

This binary is required for Helix to be able to send your time to Hackatime.

You can check that it's installed correctly through your `PATH` environment variable by running `which wakatime` (Linux/MacOS) or `where wakatime` (Windows) in your terminal.

## 5: Install `wakatime-ls`

**[github.com/mrnossiom/wakatime-ls](https://github.com/mrnossiom/wakatime-ls)**

You can either download the binary from [GitHub Releases](https://github.com/mrnossiom/wakatime-ls/releases/latest), or if you have `cargo` installed: `cargo install wakatime-ls`.

Please note that there are no binaries for Windows available on GitHub releases, if you're on Windows, you will have to use `cargo install wakatime-ls`

You can check that it's installed correctly through your `PATH` environment variable by running `which wakatime-ls` (Linux/MacOS) or `where wakatime-ls` (Windows) in your terminal.

## 6. Configure Helix's Languages

The way this method works relies on having an [LSP](https://microsoft.github.io/language-server-protocol/) tracking your code changes, as Helix does not currently have a plugin system. This means that you have to add this LSP to every language you're planning to use.

Start by creating a `languages.toml` file in the Helix configuration directory. On Linux/MacOS, this would be `~/.config/helix/languages.toml`, and on Windows it would be `%AppData%\helix\languages.toml`.

### Register the LSP

Inside Helix's `languages.toml` file, add the following content:
```toml
[language-server.wakatime]
command = "wakatime-ls"
```
This registers the Wakatime LSP in Helix, allowing it to be used for other languages.

### Add the LSP to your languages

1. Find the language you want to track in the [master `languages.toml`](https://github.com/helix-editor/helix/blob/master/languages.toml). For example, the master Rust configuration looks like this:
```toml
[[language]]
name = "rust"
scope = "source.rust"
injection-regex = "rs|rust"
file-types = ["rs"]
roots = ["Cargo.toml", "Cargo.lock"]
shebangs = ["rust-script", "cargo"]
auto-format = true
comment-tokens = ["//", "///", "//!"]
block-comment-tokens = [
  { start = "/*", end = "*/" },
  { start = "/**", end = "*/" },
  { start = "/*!", end = "*/" },
]
language-servers = [ "rust-analyzer" ]
indent = { tab-width = 4, unit = "    " }
persistent-diagnostic-sources = ["rustc", "clippy"]
```
2. Copy the `[[language]]` header, the name property, and the language servers property to your own `languages.toml`:
```toml
[[language]]
name = "rust"
language-servers = [ "rust-analyzer" ]
```
3. Add `"wakatime"` to the list of language-servers:

```toml
[[language]]
name = "rust"
language-servers = [ "rust-analyzer", "wakatime" ]
```
4. Your final `languages.toml` may look something look this:
```toml
[language-server.wakatime]
command = "wakatime-ls"

[[language]]
name = "rust"
language-servers = [ "rust-analyzer", "wakatime" ]
```
5. If you want to add more languages, simply repeat these steps! Here's an example with Ruby and Javascript:
```toml
[language-server.wakatime]
command = "wakatime-ls"

[[language]]
name = "rust"
language-servers = [ "rust-analyzer", "wakatime" ]

[[language]]
name = "ruby"
language-servers = [ "ruby-lsp", "solargraph", "wakatime" ]

[[language]]
name = "javascript"
language-servers = [ "typescript-language-server", "wakatime" ]
```

## All Done!

After you're finished setting everything up, restart Helix, then make sure to check **[hackatime.hackclub.com](https://hackatime.hackclub.com)** after a little while and ensure you're logging progress!

You can also try some **[wakatime.com/plugins](https://wakatime.com/plugins)** if you'd like to log time spent editing your project in other programs.

## Troubleshooting

- **Not seeing your time?** Make sure you completed the [setup page](https://hackatime.hackclub.com/my/wakatime_setup) first.
- **LSP hasn't started?** Type `:lsp-restart ` in Helix for it to autocomplete the active LSPs. If `wakatime` isn't listed, then it's not setup in your `languages.toml` correctly.
- **Language Server Exited?** This error will show up if you haven't installed everything correctly. Double check that `wakatime` and `wakatime-ls` are installed using `which` (Linux/MacOS) or `where` (Windows).
- **Still stuck?** Ask for help in [Hack Club Slack](https://hackclub.slack.com) (#hackatime-help channel) (@Shuflduf)
