<script lang="ts">
  import SettingsShell from "./Shell.svelte";
  import type { AdminPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    admin_tools,
    errors,
  }: AdminPageProps = $props();
</script>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
  {admin_tools}
>
  {#if admin_tools.visible}
    <div class="space-y-3">
      <h2 class="text-xl font-semibold text-surface-content">Admin</h2>
      <p class="text-sm text-muted">
        Mirror and import controls are available under Data settings for all
        users.
      </p>
    </div>
  {:else}
    <p
      class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
    >
      You are not authorized to access this section.
    </p>
  {/if}
</SettingsShell>
