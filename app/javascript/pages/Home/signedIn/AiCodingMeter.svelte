<script lang="ts">
  import { secondsToDisplay } from "./utils";

  let { stats }: { stats: Record<string, number> } = $props();

  const aiSeconds = $derived(stats["ai coding"] || 0);
  const humanSeconds = $derived(stats.coding || 0);
  const totalSeconds = $derived(aiSeconds + humanSeconds);
  const aiPercent = $derived(
    totalSeconds > 0 ? Math.round((aiSeconds / totalSeconds) * 100) : 0,
  );
  const humanPercent = $derived(totalSeconds > 0 ? 100 - aiPercent : 0);
</script>

<section
  class="flex min-h-64 flex-col rounded-2xl border border-surface-200 bg-dark p-4 sm:p-6"
>
  <div>
    <h3 class="text-lg font-semibold text-surface-content">
      AI vs Human Coding
    </h3>
    <p class="text-sm text-surface-content/55">
      Based on coding category duration
    </p>
  </div>

  <div class="my-auto py-6">
    <div
      class="flex h-5 w-full overflow-hidden rounded-full bg-surface-200/35"
      role="figure"
      aria-label={`${aiPercent}% AI coding and ${humanPercent}% human coding`}
    >
      {#if totalSeconds > 0}
        <div
          class="h-full bg-primary transition-[width] duration-300 ease-out"
          style:width={`${aiPercent}%`}
        ></div>
        <div
          class="h-full bg-blue transition-[width] duration-300 ease-out"
          style:width={`${humanPercent}%`}
        ></div>
      {/if}
    </div>

    <div class="mt-5 grid grid-cols-2 gap-4">
      <div>
        <div class="flex items-center gap-2">
          <span class="h-2.5 w-2.5 rounded-full bg-primary"></span>
          <span class="text-sm text-surface-content/60">AI coding</span>
        </div>
        <p class="mt-1 text-xl font-semibold tabular-nums text-surface-content">
          {aiPercent}%
        </p>
        <p class="text-xs text-surface-content/45">
          {secondsToDisplay(aiSeconds)}
        </p>
      </div>

      <div class="text-right">
        <div class="flex items-center justify-end gap-2">
          <span class="text-sm text-surface-content/60">Human coding</span>
          <span class="h-2.5 w-2.5 rounded-full bg-blue"></span>
        </div>
        <p class="mt-1 text-xl font-semibold tabular-nums text-surface-content">
          {humanPercent}%
        </p>
        <p class="text-xs text-surface-content/45">
          {secondsToDisplay(humanSeconds)}
        </p>
      </div>
    </div>
  </div>

  {#if totalSeconds === 0}
    <p class="text-center text-sm text-surface-content/45">
      No coding category data for this interval.
    </p>
  {/if}
</section>
