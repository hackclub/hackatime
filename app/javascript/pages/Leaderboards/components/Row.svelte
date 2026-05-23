<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import CountryFlag from "../../../components/CountryFlag.svelte";
  import StreakIcon from "../../../layouts/app/StreakIcon.svelte";
  import type { LeaderboardEntriesPayload } from "../../../types";
  import {
    secondsToDetailedDisplay,
    rankDisplay,
    streakTheme,
    streakLabel,
  } from "../utils";

  type Entry = NonNullable<LeaderboardEntriesPayload["entries"]>[number];

  let { entry, rank }: { entry: Entry; rank: number } = $props();

  const theme = $derived(streakTheme(entry.streak_count));
</script>

<div
  role="listitem"
  class="group relative flex items-center p-2 sm:p-3 hover:bg-dark transition-colors duration-200 gap-2 sm:gap-0 border-b border-gray-800 {entry
    .user.profile_path
    ? 'cursor-pointer'
    : ''} {entry.is_current_user
    ? 'bg-dark border-l-4 border-l-primary'
    : ''} {entry.user.red ? 'opacity-40 hover:opacity-60' : ''}"
>
  {#if entry.user.profile_path}
    <Link
      href={entry.user.profile_path}
      aria-label={`View ${entry.user.display_name}'s profile`}
      class="absolute inset-0 z-10 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/60"
    ></Link>
  {/if}

  <div class="w-8 sm:w-12 shrink-0 text-center font-medium text-muted">
    {#if rank <= 2}
      <span class="text-xl sm:text-2xl">{rankDisplay(rank)}</span>
    {:else}
      <span class="text-base sm:text-lg">{rank + 1}</span>
    {/if}
  </div>

  <div class="flex-1 mx-1 sm:mx-4 min-w-0">
    <div class="flex items-center gap-2">
      <div class="user-info flex items-center gap-2 min-w-0">
        {#if entry.user.avatar_url}
          <img
            src={entry.user.avatar_url}
            alt="{entry.user.display_name}'s avatar"
            class="w-8 h-8 rounded-full aspect-square border border-surface-200 shrink-0"
            loading="lazy"
          />
        {/if}
        <span class="inline-flex items-center gap-1 min-w-0">
          {#if entry.user.profile_path}
            <Link
              href={entry.user.profile_path}
              class="relative z-20 text-blue hover:underline truncate"
            >
              {entry.user.display_name}
            </Link>
          {:else}
            <span class="truncate">{entry.user.display_name}</span>
          {/if}
        </span>
        {#if entry.user.country_code}
          <CountryFlag
            countryCode={entry.user.country_code}
            class="inline-block w-5 h-5 align-middle shrink-0"
          />
        {/if}
      </div>

      {#if entry.streak_count > 0}
        <div
          class="inline-flex items-center gap-1 transition-all duration-200 {theme.hbg} group shrink-0"
          title={entry.streak_count > 30
            ? "30+ daily streak"
            : `${entry.streak_count} day streak`}
        >
          <StreakIcon size={16} class={theme.ic} />
          <span
            class="text-md font-semibold {theme.tc} transition-colors duration-200"
          >
            {streakLabel(entry.streak_count)}
          </span>
        </div>
      {/if}
    </div>
    {#if entry.active_project}
      <div class="text-xs italic text-muted truncate mt-0.5 ml-10">
        working on
        <a
          href={entry.active_project.repo_url}
          target="_blank"
          rel="noopener noreferrer"
          class="relative z-20 text-accent hover:text-cyan transition-colors"
        >
          {entry.active_project.name}
        </a>
      </div>
    {/if}
  </div>

  <div
    class="shrink-0 font-mono text-xs sm:text-sm text-surface-content font-medium whitespace-nowrap"
  >
    {secondsToDetailedDisplay(entry.total_seconds)}
  </div>
</div>
