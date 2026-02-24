<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { NotificationsPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    settings_update_path,
    user,
    errors,
    admin_tools,
  }: NotificationsPageProps = $props();

  let csrfToken = $state("");
  let weeklySummaryEmailEnabled = $state(true);

  $effect(() => {
    weeklySummaryEmailEnabled = user.weekly_summary_email_enabled;
  });

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });
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
  <div class="space-y-8">
    <section id="user_email_notifications">
      <h2 class="text-xl font-semibold text-surface-content">
        Email Notifications
      </h2>
      <p class="mt-1 text-sm text-muted">
        Control which product emails Hackatime sends to your linked email
        addresses.
      </p>

      <form method="post" action={settings_update_path} class="mt-4 space-y-4">
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <div id="user_weekly_summary_email">
          <label class="flex items-center gap-3 text-sm text-surface-content">
            <input
              type="hidden"
              name="user[weekly_summary_email_enabled]"
              value="0"
            />
            <Checkbox.Root
              bind:checked={weeklySummaryEmailEnabled}
              name="user[weekly_summary_email_enabled]"
              value="1"
              class="inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
            >
              {#snippet children({ checked })}
                <span class={checked ? "text-[10px]" : "hidden"}>✓</span>
              {/snippet}
            </Checkbox.Root>
            Weekly coding summary email (sent Fridays at 5:30 PM GMT)
          </label>
          <p class="mt-2 text-xs text-muted">
            Includes your weekly coding time, top projects, and top languages.
          </p>
        </div>

        <Button type="submit">Save notification settings</Button>
      </form>
    </section>
  </div>
</SettingsShell>
