<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { SetupPageProps } from "./types";
  import { users } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    config_file,
    errors,
  }: SetupPageProps = $props();

  const wakatimeSetupPath = users.wakatimeSetup.path();
</script>

<svelte:head>
  <title>Setup - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_tracking_setup"
    title="Time Tracking Setup"
    description="Use the setup guide if you are configuring a new editor or device."
  >
    <p class="text-sm text-muted">
      Hackatime uses the WakaTime plugin ecosystem, so the setup guide covers
      editor installation, API keys, and API URL configuration.
    </p>

    {#snippet footer()}
      <Button href={wakatimeSetupPath}>Open setup guide</Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_config_file"
    title="WakaTime Config File"
    description="Copy this into your ~/.wakatime.cfg file."
    wide
  >
    {#if config_file.has_api_key && config_file.content}
      <pre
        class="overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 text-xs text-surface-content">{config_file.content}</pre>
    {:else}
      <p
        class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
      >
        {config_file.empty_message}
      </p>
    {/if}
  </SectionCard>
</SettingsShell>
