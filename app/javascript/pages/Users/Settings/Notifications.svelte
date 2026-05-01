<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { Checkbox } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
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
  }: NotificationsPageProps = $props();
</script>

<svelte:head>
  <title>Notifications - Hackatime Settings</title>
</svelte:head>

<SettingsShell
  {active_section}
  {section_paths}
  {page_title}
  {heading}
  {subheading}
  {errors}
>
  <SectionCard
    id="user_email_notifications"
    title="Email Notifications"
    description="Control which product emails Hackatime sends to your linked email addresses."
  >
    <Form
      id="notifications-settings-form"
      action={settings_update_path}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
    >
      <div id="user_weekly_summary_email">
        <label class="flex items-center gap-3 text-sm text-surface-content">
          <input
            type="hidden"
            name="user[weekly_summary_email_enabled]"
            value="0"
          />
          <Checkbox.Root
            bind:checked={user.weekly_summary_email_enabled}
            name="user[weekly_summary_email_enabled]"
            value="1"
            class="inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
          >
            {#snippet children({ checked })}
              <span class={checked ? "text-[10px]" : "hidden"}>✓</span>
            {/snippet}
          </Checkbox.Root>
          Weekly coding summary email (sent Sundays at 6:30 PM GMT)
        </label>
        <p class="mt-2 text-xs text-muted">
          Includes your weekly coding time, top projects, and top languages.
        </p>
      </div>
    </Form>

    {#snippet footer()}
      <Button type="submit" form="notifications-settings-form">
        Save notification settings
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>
