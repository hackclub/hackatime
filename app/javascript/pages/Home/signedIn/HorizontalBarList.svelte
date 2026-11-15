<script lang="ts">
  import { secondsToDisplay, percentOf, logScale } from "./utils";

  let {
    title,
    entries,
    empty_message = "No data yet.",
    useLogScale = false,
  }: {
    title: string;
    entries: [string, number][];
    empty_message?: string;
    useLogScale?: boolean;
  } = $props();

  const maxVal = $derived(Math.max(...entries.map(([_, v]) => v || 0), 1));
  const barWidth = (s: number) =>
    useLogScale ? logScale(s, maxVal) : percentOf(s, maxVal);
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col h-full"
>
  <h3 class="text-lg font-semibold mb-4 text-surface-content/90">{title}</h3>
  {#if entries.length > 0}
    <div class="space-y-2.5 overflow-y-auto flex-1 pr-2 custom-scrollbar">
      {#each entries as [label, seconds]}
        <div class="flex items-center gap-4 group">
          <div
            class="w-1/3 truncate font-medium text-sm text-muted text-right group-hover:text-surface-content transition-colors"
            title={label}
          >
            {label}
          </div>
          <div class="flex-1">
            <div
              class="bg-primary rounded-md h-6"
              style={`width:${barWidth(seconds)}%`}
            ></div>
          </div>
          <span
            class="w-20 shrink-0 text-xs font-mono text-muted whitespace-nowrap"
          >
            {secondsToDisplay(seconds)}
          </span>
        </div>
      {/each}
    </div>
  {:else}
    <p class="text-muted text-sm italic">{empty_message}</p>
  {/if}
</div>
