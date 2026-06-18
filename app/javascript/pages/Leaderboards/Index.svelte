<script lang="ts">
  import { Deferred, Link } from "@inertiajs/svelte";
  import { Icon, MagnifyingGlass } from "svelte-hero-icons";
  import Tabs from "./components/Tabs.svelte";
  import EntriesList from "./components/EntriesList.svelte";
  import type {
    LeaderboardMeta,
    LeaderboardCountry,
    LeaderboardEntriesPayload,
  } from "../../types";
  import { timeAgo } from "./utils";
  import { settingsProfile } from "../../api";

  let {
    period_type,
    scope,
    country,
    leaderboard,
    is_logged_in,
    github_uid_blank,
    entries,
  }: {
    period_type: string;
    scope: string;
    country: LeaderboardCountry;
    leaderboard: LeaderboardMeta | null;
    is_logged_in: boolean;
    github_uid_blank: boolean;
    entries?: LeaderboardEntriesPayload;
  } = $props();

  const settingsPath = settingsProfile.mySettings.path();
  let searchQuery = $state("");

  const filteredEntries = $derived.by(() => {
    if (!entries?.entries) return [];
    const q = searchQuery.trim().toLowerCase();
    if (!q) return entries.entries;
    return entries.entries.filter((e) =>
      [
        e.user.display_name,
        e.user.profile_path,
        e.user.country_code,
        e.active_project?.name,
      ]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(q),
    );
  });

  const entryRank = $derived.by(() => {
    const map = new Map<number, number>();
    entries?.entries?.forEach((e, i) => map.set(e.user_id, i));
    return map;
  });

  const dateRangeText = $derived(
    leaderboard?.date_range_text ??
      (period_type === "last_7_days"
        ? (() => {
            const end = new Date();
            const start = new Date(end);
            start.setDate(start.getDate() - 6);
            return `${start.toLocaleDateString("en-US", { month: "long", day: "numeric" })} - ${end.toLocaleDateString("en-US", { month: "long", day: "numeric", year: "numeric" })}`;
          })()
        : "Last 24 hours"),
  );

  const periodLabel = $derived(
    period_type === "last_7_days" ? "last 7 days" : "last 24 hours",
  );
</script>

<svelte:head>
  <title>Leaderboards | Hackatime</title>
</svelte:head>

<div>
  <div class="mb-6 sm:mb-8 space-y-4">
    <h1 class="text-2xl sm:text-3xl font-bold text-surface-content">
      Leaderboards
    </h1>

    <div class="flex flex-row items-center justify-between gap-3">
      <Tabs {period_type} {scope} {country} />
    </div>

    {#if is_logged_in && !country.available}
      <p class="text-xs text-muted">
        Set your country in
        <Link
          href={settingsPath}
          class="text-accent hover:text-cyan transition-colors">settings</Link
        >
        to unlock regional leaderboards.
      </p>
    {/if}

    <div
      class="text-muted text-sm flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
        {dateRangeText}
        {#if leaderboard?.finished_generating && leaderboard?.updated_at}
          <span class="italic"
            >• Updated {timeAgo(leaderboard.updated_at)}.</span
          >
        {/if}
      </div>

      {#if entries === undefined || entries.total > 0}
        <div class="relative w-full sm:w-64 sm:shrink-0">
          <label for="leaderboard-search" class="sr-only"
            >Find a leaderboard user</label
          >
          <Icon
            src={MagnifyingGlass}
            size="16"
            class="absolute left-3 top-1/2 -translate-y-1/2 text-muted pointer-events-none"
          />
          <input
            id="leaderboard-search"
            type="search"
            bind:value={searchQuery}
            placeholder="Find user"
            disabled={entries === undefined}
            class="h-9 w-full rounded-full border border-surface-200 bg-darkless pl-9 pr-3 text-sm text-surface-content placeholder:text-muted focus:border-primary/60 focus:outline-none focus:ring-2 focus:ring-primary/30 transition-colors disabled:opacity-60"
          />
        </div>
      {/if}
    </div>
  </div>

  <div class="bg-elevated rounded-xl border border-surface-200 overflow-hidden">
    {#if leaderboard}
      <Deferred data="entries">
        {#snippet fallback()}
          <div>
            {#each Array(20) as _}
              <div
                class="flex items-center p-2 sm:p-3 gap-2 sm:gap-0 border-b border-gray-800 animate-pulse"
              >
                <div class="w-8 sm:w-12 shrink-0 flex justify-center">
                  <div class="h-5 w-5 bg-darkless rounded"></div>
                </div>
                <div class="flex-1 mx-1 sm:mx-4 min-w-0 flex items-center gap-2">
                  <div class="w-8 h-8 bg-darkless rounded-full shrink-0"></div>
                  <div class="h-4 w-32 max-w-full bg-darkless rounded"></div>
                </div>
                <div class="h-4 w-16 bg-darkless rounded shrink-0"></div>
              </div>
            {/each}
          </div>
        {/snippet}

        {#snippet children()}
          <EntriesList
            {entries}
            {filteredEntries}
            {entryRank}
            {searchQuery}
            {leaderboard}
            {github_uid_blank}
            {period_type}
          />
        {/snippet}
      </Deferred>
    {:else}
      <div class="py-16 text-center px-3">
        <h3 class="text-xl font-medium text-surface-content mb-2">
          Leaderboard is being generated...
        </h3>
        <p class="text-muted">
          Check back in a moment for {scope === "country" && country.name
            ? `${country.name} `
            : ""}{periodLabel} results!
        </p>
      </div>
    {/if}
  </div>
</div>
