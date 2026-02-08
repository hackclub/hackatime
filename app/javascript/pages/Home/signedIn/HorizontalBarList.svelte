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
  const barWidth = (seconds: number) =>
    useLogScale ? logScale(seconds, maxVal) : percentOf(seconds, maxVal);
</script>

<div class="bg-dark border border-primary rounded-xl p-6 flex flex-col">
  <h3 class="text-xl font-semibold mb-4">{title}</h3>
  {#if entries.length > 0}
    <div class="space-y-3">
      {#each entries as [label, seconds]}
        <div class="flex items-center gap-3">
          <div class="w-1/3 truncate font-medium text-white" title={label}>
            {label}
          </div>
          <div class="flex-1 bg-darkless rounded h-3 overflow-hidden">
            <div
              class="h-3 bg-primary rounded"
              style={`width:${barWidth(seconds)}%`}
            ></div>
          </div>
          <div class="w-16 text-sm text-muted text-right">
            {secondsToDisplay(seconds)}
          </div>
        </div>
      {/each}
    </div>
  {:else}
    <p class="text-muted">{empty_message}</p>
  {/if}
</div>
