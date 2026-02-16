<script lang="ts">
  import { Checkbox } from "bits-ui";
  import { onMount } from "svelte";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
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
    admin_tools,
  }: IntegrationsPageProps = $props();

  let csrfToken = $state("");
  let usesSlackStatus = $state(user.uses_slack_status);
  let unlinkGithubModalOpen = $state(false);

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
    <section id="user_slack_status">
      <h2 class="text-xl font-semibold text-surface-content">Slack Status Sync</h2>
      <p class="mt-1 text-sm text-muted">
        Keep your Slack status updated while you are actively coding.
      </p>

      {#if !slack.can_enable_status}
        <a
          href={paths.slack_auth_path}
          class="mt-4 inline-flex rounded-md border border-surface-200 bg-surface-100 px-3 py-2 text-sm text-surface-content transition-colors hover:bg-surface-200"
        >
          Re-authorize with Slack
        </a>
      {/if}

      <form method="post" action={settings_update_path} class="mt-4 space-y-3">
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

        <Button type="submit">Save Slack settings</Button>
      </form>
    </section>

    <section id="user_slack_notifications">
      <h2 class="text-xl font-semibold text-surface-content">Slack Channel Notifications</h2>
      <p class="mt-1 text-sm text-muted">
        Enable notifications in any channel by running
        <code class="rounded bg-darker px-1 py-0.5 text-xs text-surface-content">
          /sailorslog on
        </code>
        in that channel.
      </p>

      {#if slack.notification_channels.length > 0}
        <ul class="mt-4 space-y-2">
          {#each slack.notification_channels as channel}
            <li class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content">
              <a href={channel.url} target="_blank" class="underline">{channel.label}</a>
            </li>
          {/each}
        </ul>
      {:else}
        <p class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
          No channel notifications are enabled.
        </p>
      {/if}
    </section>

    <section id="user_github_account">
      <h2 class="text-xl font-semibold text-surface-content">Connected GitHub Account</h2>
      <p class="mt-1 text-sm text-muted">
        Connect GitHub to show project links in dashboards and leaderboards.
      </p>

      {#if github.connected && github.username}
        <div class="mt-4 rounded-md border border-surface-200 bg-darker px-3 py-3 text-sm text-surface-content">
          Connected as
          <a href={github.profile_url || "#"} target="_blank" class="underline">
            @{github.username}
          </a>
        </div>
        <div class="mt-3 flex flex-wrap gap-3">
          <a
            href={paths.github_auth_path}
            class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
          >
            Reconnect GitHub
          </a>
          <Button
            type="button"
            variant="surface"
            class="rounded-md"
            onclick={() => (unlinkGithubModalOpen = true)}
          >
            Unlink GitHub
          </Button>
        </div>
      {:else}
        <Button
          href={paths.github_auth_path}
          native
          class="mt-4 rounded-md"
        >
          Connect GitHub
        </Button>
      {/if}
    </section>

    <section id="user_email_addresses">
      <h2 class="text-xl font-semibold text-surface-content">Email Addresses</h2>
      <p class="mt-1 text-sm text-muted">
        Add or remove email addresses used for sign-in and verification.
      </p>

      <div class="mt-4 space-y-2">
        {#if emails.length > 0}
          {#each emails as email}
            <div class="flex flex-wrap items-center gap-2 rounded-md border border-surface-200 bg-darker px-3 py-2">
              <div class="grow text-sm text-surface-content">
                <p>{email.email}</p>
                <p class="text-xs text-muted">{email.source}</p>
              </div>
              {#if email.can_unlink}
                <form method="post" action={paths.unlink_email_path}>
                  <input type="hidden" name="_method" value="delete" />
                  <input type="hidden" name="authenticity_token" value={csrfToken} />
                  <input type="hidden" name="email" value={email.email} />
                  <Button
                    type="submit"
                    variant="surface"
                    size="xs"
                    class="rounded-md"
                  >
                    Unlink
                  </Button>
                </form>
              {/if}
            </div>
          {/each}
        {:else}
          <p class="rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-muted">
            No email addresses are linked.
          </p>
        {/if}
      </div>

      <form method="post" action={paths.add_email_path} class="mt-4 flex flex-col gap-3 sm:flex-row">
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <input
          type="email"
          name="email"
          required
          placeholder="name@example.com"
          class="grow rounded-md border border-surface-200 bg-darker px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none"
        />
        <Button
          type="submit"
          class="rounded-md"
        >
          Add email
        </Button>
      </form>
    </section>
  </div>
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
        <Button type="submit" variant="primary" class="h-10 w-full text-on-primary">
          Unlink GitHub
        </Button>
      </form>
    </div>
  {/snippet}
</Modal>
