![Hackatime Desktop](assets/banner.png)

# Hackatime Desktop

A Mac app that tracks your editor, terminal, browser and AI tools, and backs every minute with evidence the server can check. Faking it costs more than doing the work.

- **Passive tracking:** the focused window is classified on your Mac as project, research, unrelated or unknown. Titles and URLs never leave it. The app keeps three days of which window was in front, encrypted in the vault, only to show you the review timeline.
- **You edit a ship before it is sent:** shipping opens a timeline of the time it covers, with the timelapse frames and the apps that were in front, like clips in a video editor. Drag over time, click a window's stretch or take an app out altogether; a removed minute earns nothing and nothing from it is sent. After that you see each frame the server asks for and can black parts out.
- **AI tools:** hooks for Claude Code, Codex and Amp send counts, tokens and line totals, never prompt text (`hooks/`).
- **Proof of time:** one signed, beacon-linked hash chain block per minute, plus salted Merkle roots of your working tree. The Secure Enclave signs when available, and App Attest is used on macOS 27+.
- **A timelapse, private until shipped:** pairing means agreeing to it. One frame a minute of the focused window, allowlisted windows only, with secrets blacked out, encrypted on your Mac and destroyed there after 30 days. Only the frames you ship ever leave it.
- **A native window onto the companion site:** pairing happens inside it, with native toasts for what the app does. Close it and tracking carries on from the menu bar.
- **No** keylogging, camera, kernel driver, source upload while working, or required hardware.

The full protocol is in [PROTOCOL.md](PROTOCOL.md).

## Build (Xcode 27; runs on macOS 14+)

```sh
cd desktop/macos
swift test                 # protocol vectors shared with the server, chain, vault, classifier
./scripts/bundle.sh        # build/Hackatime Desktop.app (ad-hoc signed)
```

To see which platform features work on a Mac (device key, App Attest, permissions, capture), run `"build/Hackatime Desktop.app/Contents/MacOS/HackatimeDesktop" --self-test`. It checks locally and sends nothing to Hackatime.

For App Attest, sign with Developer ID: `SIGN_IDENTITY=… TEAM_ID=… PROFILE=…/profile.provisionprofile ./scripts/bundle.sh`, then notarise. The server needs `DESKTOP_APP_ATTEST_APP_ID=TEAMID.com.hackclub.hackatime.desktop`.

## Permissions

All optional. The app works with less information when one is missing; a missing permission never counts against you.

| Permission | Used for |
| --- | --- |
| Accessibility | window title and browser address, classified on device |
| Input Monitoring | input counts and where events came from (no key codes) |
| Screen Recording | timelapse frames of the focused window |

## AI hooks

Put `hooks/hackatime-ai-hook` on your `PATH`, then:

- Claude Code: merge `hooks/claude-code-settings.json` into `~/.claude/settings.json`.
- Codex: `notify = ["hackatime-ai-hook", "codex"]` in `~/.codex/config.toml`.
- Amp: `mkdir -p ~/.config/amp/plugins && cp hooks/amp-plugin.ts ~/.config/amp/plugins/hackatime.ts`, then run `plugins: reload` from Amp's command palette.

## Privacy and young users

Pairing needs an explicit tick agreeing to the timelapse on the companion site's pairing page (`site/`). Pause, the vault folder and "Delete all local evidence" are in the menu. The companion site lists your Macs, your shipped projects and, for each ship, an access log of every reviewer view. Account erasure removes all desktop data.
