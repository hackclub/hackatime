<script lang="ts">
  import plur from "plur";
  import Button from "./Button.svelte";
  import type { CurrentlyHackingUser, LayoutProps } from "../types";

  let {
    currentlyHacking,
  }: { currentlyHacking: LayoutProps["currently_hacking"] } = $props();

  let expanded = $state(false);

  const toggleExpanded = () => {
    expanded = !expanded;
  };

  const countLabel = () =>
    `${currentlyHacking.count} ${plur("person", currentlyHacking.count)} currently hacking`;

  const visualizeGitUrl = (url?: string | null) =>
    url
      ? `https://maxwofford.com/dandelion/?url=${encodeURIComponent(url)}`
      : "";
</script>

{#snippet currentlyHackingUser(user: CurrentlyHackingUser)}
  <div
    class="flex flex-col space-y-1 p-2 rounded-md hover:bg-dark transition-colors"
  >
    <div class="flex items-center gap-2">
      {#if user.avatar_url}
        <img
          src={user.avatar_url}
          alt={`${user.display_name || `User ${user.id}`}'s avatar`}
          class="w-6 h-6 rounded-full aspect-square flex-shrink-0"
          loading="lazy"
        />
      {/if}
      {#if user.slack_uid}
        <a
          href={`https://hackclub.slack.com/team/${user.slack_uid}`}
          target="_blank"
          class="text-blue hover:underline text-sm"
        >
          @{user.display_name || `User ${user.id}`}
        </a>
      {:else}
        <span class="text-surface-content text-sm">
          {user.display_name || `User ${user.id}`}
        </span>
      {/if}
    </div>
    {#if user.active_project}
      <div class="text-xs text-muted ml-8">
        working on
        {#if user.active_project.repo_url}
          <a
            href={user.active_project.repo_url}
            target="_blank"
            class="text-accent hover:text-cyan transition-colors"
          >
            {user.active_project.name}
          </a>
        {:else}
          {user.active_project.name}
        {/if}
        {#if visualizeGitUrl(user.active_project.repo_url)}
          <a
            href={visualizeGitUrl(user.active_project.repo_url)}
            target="_blank"
            class="ml-1">🌌</a
          >
        {/if}
      </div>
    {/if}
  </div>
{/snippet}

<div
  class="fixed top-0 right-5 max-w-sm max-h-[80vh] bg-dark border border-darkless rounded-b-xl shadow-lg z-1000 overflow-hidden transform transition-transform duration-300 ease-out"
>
  <Button
    type="button"
    unstyled
    class="currently-hacking p-3 bg-dark cursor-pointer select-none flex items-center justify-between"
    onclick={toggleExpanded}
    aria-expanded={expanded}
    aria-label="Toggle currently hacking list"
  >
    <div class="text-surface-content text-sm font-medium">
      <div class="flex items-center">
        <div class="w-2 h-2 rounded-full bg-green animate-pulse mr-2"></div>
        <span class="text-base">{countLabel()}</span>
      </div>
    </div>
  </Button>

  {#if expanded}
    {#if currentlyHacking.users.length === 0}
      <div class="p-4 bg-dark">
        <div class="text-center text-muted text-sm italic">
          No one is currently hacking :(
        </div>
      </div>
    {:else}
      <div
        class="currently-hacking-list max-h-[60vh] max-w-100 overflow-y-auto p-2 bg-darker"
      >
        <div class="space-y-2">
          {#each currentlyHacking.users as user}
            {@render currentlyHackingUser(user)}
          {/each}
        </div>
      </div>
    {/if}
  {/if}
</div>
