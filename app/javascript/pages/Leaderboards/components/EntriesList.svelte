<script lang="ts">
  import { WindowVirtualizer } from "virtua/svelte";
  import Button from "../../../components/Button.svelte";
  import Row from "./Row.svelte";
  import type {
    LeaderboardEntriesPayload,
    LeaderboardMeta,
  } from "../../../types";
  import { sessions } from "../../../api";

  let {
    entries,
    filteredEntries,
    entryRank,
    searchQuery,
    leaderboard,
    github_uid_blank,
    period_type,
  }: {
    entries?: LeaderboardEntriesPayload;
    filteredEntries: NonNullable<LeaderboardEntriesPayload["entries"]>;
    entryRank: Map<number, number>;
    searchQuery: string;
    leaderboard: LeaderboardMeta;
    github_uid_blank: boolean;
    period_type: string;
  } = $props();

  const githubAuthPath = sessions.githubNew.path();
</script>

{#if github_uid_blank}
  <div
    class="rounded-t-xl border border-yellow/30 bg-yellow/10 p-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-2"
  >
    <p class="text-base font-medium text-surface-content">
      Connect your GitHub to qualify for the leaderboard.
    </p>
    <Button href={githubAuthPath} native class="w-full sm:w-fit shrink-0">
      Connect GitHub
    </Button>
  </div>
{/if}

{#if entries && entries.total > 0}
  {#if filteredEntries.length === 0}
    <div class="py-16 text-center px-3">
      <h3 class="text-xl font-medium text-surface-content mb-2">No matches</h3>
      <p class="text-muted">No users matching "{searchQuery}".</p>
    </div>
  {:else}
    <WindowVirtualizer
      data={filteredEntries}
      getKey={(entry) => entry.user_id}
      itemSize={64}
      bufferSize={2_000}
    >
      {#snippet children(entry)}
        <Row {entry} rank={entryRank.get(entry.user_id) ?? 0} />
      {/snippet}
    </WindowVirtualizer>

    {#if leaderboard.finished_generating && leaderboard.generation_duration_seconds != null}
      <div
        class="px-4 py-2 text-xs italic text-muted border-t border-surface-200"
      >
        Generated in {leaderboard.generation_duration_seconds} seconds
      </div>
    {/if}
  {/if}
{:else}
  <div class="py-16 text-center px-3">
    <h3 class="text-xl font-medium text-surface-content mb-2">
      No data available
    </h3>
    <p class="text-muted">
      Check back later for {period_type === "last_7_days"
        ? "last 7 days"
        : "last 24 hours"} results!
    </p>
  </div>
{/if}
