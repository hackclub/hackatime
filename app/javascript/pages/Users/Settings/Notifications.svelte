<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import CheckboxField from "./components/CheckboxField.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { NotificationsPageProps } from "./types";
  import { settingsNotifications } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    user,
    errors,
  }: NotificationsPageProps = $props();
</script>

<svelte:head>
  <title>Notifications - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_email_notifications"
    title="Email Notifications"
    description="Control which product emails Hackatime sends to your linked email addresses."
  >
    <Form
      id="notifications-settings-form"
      action={settingsNotifications.update.path()}
      method="patch"
      class="space-y-4"
      options={{ preserveScroll: true }}
    >
      <div id="user_weekly_summary_email">
        <CheckboxField
          name="user[weekly_summary_email_enabled]"
          bind:checked={user.weekly_summary_email_enabled}
          label="Weekly coding summary email (sent Sundays at 6:30 PM GMT)"
        />
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
