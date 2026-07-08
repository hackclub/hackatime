# /setup flow: deferred work

The new `/setup` page (app/javascript/pages/Setup/) replaced the old 4-step
`my/wakatime_setup` flow. These pieces were intentionally left out of the
first version.

## No Terminal (manual) branch

The "No Terminal (manual)" card on the terminal-choice screen currently
navigates to `/docs` as a stopgap. Build an in-flow manual branch that walks
the user through installing the editor extension by hand (the old
`WakatimeSetup/Step2` and `Step3` per-editor instructions are a reference,
see git history).

## VSCode download continuation

After the "Yeah! I can install programs" → VSCode download screen, "I'm
done!" currently goes straight to the finish screen. It should instead
continue to the terminal-choice screen (`step = "terminal-choice"`) so the
user actually installs Hackatime in their new editor. One-line change in
`app/javascript/pages/Setup/Index.svelte` once the manual branch exists.

## Codespaces screenshots

`app/javascript/pages/Setup/CodespacesSteps.svelte` references three images
that still need to be added:

- public/images/setup/codespaces-step-1.png (extension menu in the sidebar)
- public/images/setup/codespaces-step-2.png (searching "Hackatime")
- public/images/setup/codespaces-step-3.png (installing "Hackatime Time Tracker")

## Setup-complete polling

The old flow polled `api_v1_my_heartbeats_most_recent` to verify heartbeats
arrived (`HeartbeatPanel.svelte`, see git history). The new flow trusts the
user's "I'm done!". Consider re-adding a lightweight verification on the
finish screen.
