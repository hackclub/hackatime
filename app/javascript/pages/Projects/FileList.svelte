<script lang="ts">
  import { secondsToDisplay } from "../Home/signedIn/utils";

  let {
    entries,
    initialVisible = 5,
    totalFileCount = 0,
  }: {
    entries: [string, number][];
    initialVisible?: number;
    totalFileCount?: number;
  } = $props();

  let expanded = $state(false);

  const visibleEntries = $derived(
    expanded ? entries : entries.slice(0, initialVisible),
  );
  const hasMore = $derived(entries.length > initialVisible);
  const hiddenCount = $derived(entries.length - initialVisible);
  const unlistedCount = $derived(
    totalFileCount > entries.length ? totalFileCount - entries.length : 0,
  );
</script>

<div
  class="rounded-xl border border-surface-200 bg-dark/50 p-6"
>
  <div class="mb-4 flex items-baseline justify-between gap-2">
    <h3 class="text-lg font-semibold text-surface-content/90">Files</h3>
    {#if totalFileCount > 0}
      <span class="text-xs text-muted">
        {entries.length} shown · {totalFileCount} total
      </span>
    {/if}
  </div>

  {#if entries.length > 0}
    <div class="divide-y divide-surface-200/30">
      {#each visibleEntries as [label, seconds]}
        <div class="flex items-center justify-between gap-4 py-2.5">
          <span
            class="min-w-0 flex-1 truncate font-mono text-sm text-surface-content/80"
            title={label}
          >
            {label}
          </span>
          <span class="shrink-0 font-mono text-sm font-medium text-primary">
            {secondsToDisplay(seconds)}
          </span>
        </div>
      {/each}
    </div>

    {#if hasMore}
      <button
        type="button"
        class="mt-3 w-full rounded-lg border border-surface-200/40 py-2 text-center text-sm text-muted transition-colors hover:border-primary/40 hover:text-primary"
        onclick={() => (expanded = !expanded)}
      >
        {expanded
          ? "Show fewer"
          : `Show ${hiddenCount} more file${hiddenCount === 1 ? "" : "s"}`}
      </button>
    {/if}

    {#if unlistedCount > 0}
      <p class="mt-2 text-center text-xs text-muted">
        + {unlistedCount} file{unlistedCount === 1 ? "" : "s"} under 1 min not shown
      </p>
    {/if}
  {:else}
    <p class="text-sm italic text-muted">No file data yet.</p>
  {/if}
</div>
