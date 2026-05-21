<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import { Checkbox } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import SectionCard from "./components/SectionCard.svelte";
  import SettingsShell from "./Shell.svelte";
  import type { SlackGithubPageProps } from "./types";
  import { sessions, settingsSlackGithub } from "../../../api";

  let {
    active_section,
    page_title,
    heading,
    subheading,
    user,
    slack,
    github,
    errors,
  }: SlackGithubPageProps = $props();

  const settingsUpdatePath = settingsSlackGithub.update.path();
  const slackAuthPath = sessions.slackNew.path();
  const githubAuthPath = sessions.githubNew.path();
  const githubUnlinkPath = sessions.githubUnlink.path();

  let unlinkGithubModalOpen = $state(false);
</script>

<svelte:head>
  <title>Slack & GitHub - Hackatime Settings</title>
</svelte:head>

<SettingsShell {active_section} {page_title} {heading} {subheading} {errors}>
  <SectionCard
    id="user_slack_status"
    title="Slack Status Sync"
    description="Keep your Slack status updated while you are actively coding."
  >
    <div class="space-y-4">
      {#if !slack.can_enable_status}
        <a
          href={slackAuthPath}
          class="inline-flex rounded-md border border-surface-200 bg-surface-100 px-3 py-2 text-sm text-surface-content transition-colors hover:bg-surface-200"
        >
          Re-authorize with Slack
        </a>
      {/if}

      <Form
        id="slack-github-slack-form"
        action={settingsUpdatePath}
        method="patch"
        class="space-y-3"
        options={{ preserveScroll: true }}
      >
        <label class="flex items-center gap-3 text-sm text-surface-content">
          <input type="hidden" name="user[uses_slack_status]" value="0" />
          <Checkbox.Root
            bind:checked={user.uses_slack_status}
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
      </Form>
    </div>

    {#snippet footer()}
      <Button type="submit" form="slack-github-slack-form">
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
        <Button href={githubAuthPath} native class="rounded-md">
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
        <Button href={githubAuthPath} native class="rounded-md">
          Connect GitHub
        </Button>
      {/if}
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
      <Form
        action={githubUnlinkPath}
        method="delete"
        class="m-0"
        options={{ preserveScroll: true }}
      >
        <Button
          type="submit"
          variant="primary"
          class="h-10 w-full text-on-primary"
        >
          Unlink GitHub
        </Button>
      </Form>
    </div>
  {/snippet}
</Modal>
