<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { IntegrationsPageProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    settings_update_path,
    user,
    slack,
    github,
    emails,
    paths,
    errors,
  }: IntegrationsPageProps = $props();

  let csrfToken = $state("");
  let usesSlackStatus = $state(false);
  let unlinkGithubModalOpen = $state(false);

  $effect(() => {
    usesSlackStatus = user.uses_slack_status;
  });

  onMount(() => {
    csrfToken =
      document
        .querySelector("meta[name='csrf-token']")
        ?.getAttribute("content") || "";
  });

  function formatCooldown(seconds: number): string {
    if (seconds <= 0) return "";

    const minutes = Math.ceil(seconds / 60);
    return `Resend in ${minutes}m`;
  }
</script>

<svelte:head>
  <title>Integrations - Hackatime Settings</title>
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
    id="user_slack_status"
    title="Slack Status Sync"
    description="Keep your Slack status updated while you are actively coding."
  >
    <div class="space-y-4">
      {#if !slack.can_enable_status}
        <a
          href={paths.slack_auth_path}
          class="inline-flex rounded-md border border-surface-200 bg-surface-100 px-3 py-2 text-sm text-surface-content transition-colors hover:bg-surface-200"
        >
          Re-authorize with Slack
        </a>
      {/if}

      <form
        id="integrations-slack-form"
        method="post"
        action={settings_update_path}
        class="space-y-3"
      >
        <input type="hidden" name="_method" value="patch" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <label class="flex items-center gap-3 text-sm text-surface-content">
          <input type="hidden" name="user[uses_slack_status]" value="0" />
          <Checkbox.Root
            bind:checked={usesSlackStatus}
            name="user[uses_slack_status]"
            value="1"
            class="inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary"
          >
            {#snippet children({ checked })}
              <span class={checked ? "text-[10px]" : "hidden"}>✓</span>
            {/snippet}
          </Checkbox.Root>
          Update my Slack status automatically
        </label>
      </form>
    </div>

    {#snippet footer()}
      <Button type="submit" form="integrations-slack-form">
        Save Slack settings
      </Button>
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_slack_notifications"
    title="Slack Channel Notifications"
    description="Enable notifications in any channel by running /sailorslog on in that channel."
  >
    <p class="text-sm text-muted">
      Command:
      <code class="rounded bg-darker px-1 py-0.5 text-xs text-surface-content">
        /sailorslog on
      </code>
    </p>

    {#if slack.notification_channels.length > 0}
      <ul class="mt-4 space-y-2">
        {#each slack.notification_channels as channel}
          <li
            class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content"
          >
            <a href={channel.url} target="_blank" class="underline"
              >{channel.label}</a
            >
          </li>
        {/each}
      </ul>
    {:else}
      <p
        class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
      >
        No channel notifications are enabled.
      </p>
    {/if}
  </SectionCard>

  <SectionCard
    id="user_github_account"
    title="Connected GitHub Account"
    description="Connect GitHub to show project links in dashboards and leaderboards."
    hasBody={Boolean(github.connected && github.username)}
  >
    {#if github.connected && github.username}
      <div
        class="rounded-md border border-surface-200 bg-darker px-3 py-3 text-sm text-surface-content"
      >
        Connected as
        <a href={github.profile_url || "#"} target="_blank" class="underline">
          @{github.username}
        </a>
      </div>
    {/if}

    {#snippet footer()}
      {#if github.connected && github.username}
        <Button href={paths.github_auth_path} native class="rounded-md">
          Reconnect GitHub
        </Button>
        <Button
          type="button"
          variant="surface"
          class="rounded-md"
          onclick={() => (unlinkGithubModalOpen = true)}
        >
          Unlink GitHub
        </Button>
      {:else}
        <Button href={paths.github_auth_path} native class="rounded-md">
          Connect GitHub
        </Button>
      {/if}
    {/snippet}
  </SectionCard>

  <SectionCard
    id="user_email_addresses"
    title="Email Addresses"
    description="Add or remove email addresses used for sign-in and verification."
  >
    <div class="space-y-2">
      {#if emails.length > 0}
        {#each emails as email}
          <div
            class="flex flex-wrap items-center gap-2 rounded-md border border-surface-200 bg-darker px-3 py-2"
          >
            <div class="grow text-sm text-surface-content">
              <p class="flex items-center gap-2">
                <span>{email.email}</span>
                {#if email.pending}
                  <span
                    class="rounded-md border border-surface-200 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted"
                  >
                    Unverified
                  </span>
                  {#if email.expired}
                    <span
                      class="rounded-md border border-surface-200 px-1.5 py-0.5 text-[10px] uppercase tracking-wide text-muted"
                    >
                      Expired
                    </span>
                  {/if}
                {/if}
              </p>
              <p class="text-xs text-muted">{email.source}</p>
            </div>
            {#if email.pending}
              <form method="post" action={paths.resend_email_verification_path}>
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={csrfToken}
                />
                <input type="hidden" name="email" value={email.email} />
                <Button
                  type="submit"
                  variant="surface"
                  size="xs"
                  class="rounded-md"
                  disabled={!email.can_resend}
                >
                  {email.can_resend
                    ? "Resend"
                    : formatCooldown(email.resend_cooldown_seconds) ||
                      "Resend soon"}
                </Button>
              </form>
            {/if}
            {#if email.can_unlink}
              <form method="post" action={paths.unlink_email_path}>
                <input type="hidden" name="_method" value="delete" />
                <input
                  type="hidden"
                  name="authenticity_token"
                  value={csrfToken}
                />
                <input type="hidden" name="email" value={email.email} />
                <Button
                  type="submit"
                  variant="surface"
                  size="xs"
                  class="rounded-md"
                >
                  Remove
                </Button>
              </form>
            {/if}
          </div>
        {/each}
      {:else}
        <p
          class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted"
        >
          No email addresses are linked.
        </p>
      {/if}
    </div>

    <form
      id="integrations-email-form"
      method="post"
      action={paths.add_email_path}
      class="mt-4 flex flex-col gap-3 sm:flex-row"
    >
      <input type="hidden" name="authenticity_token" value={csrfToken} />
      <input
        type="email"
        name="email"
        required
        placeholder="name@example.com"
        class="grow rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
      />
    </form>

    {#snippet footer()}
      <Button type="submit" class="rounded-md" form="integrations-email-form">
        Add email
      </Button>
    {/snippet}
  </SectionCard>
</SettingsShell>

<Modal
  bind:open={unlinkGithubModalOpen}
  title="Unlink GitHub account?"
  description="GitHub-based features will stop until you reconnect."
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={() => (unlinkGithubModalOpen = false)}
      >
        Cancel
      </Button>
      <form method="post" action={paths.github_unlink_path} class="m-0">
        <input type="hidden" name="_method" value="delete" />
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <Button
          type="submit"
          variant="primary"
          class="h-10 w-full text-on-primary"
        >
          Unlink GitHub
        </Button>
      </form>
    </div>
  {/snippet}
</Modal>
