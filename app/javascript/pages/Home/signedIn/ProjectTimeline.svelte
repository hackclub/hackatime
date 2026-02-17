<script lang="ts">
  import { secondsToDisplay, percentOf } from "./utils";

  let {
    entries,
  }: {
    entries: [string, Record<string, number>][];
  } = $props();
</script>

<div
  class="bg-dark border border-primary rounded-xl p-6 flex flex-col md:col-span-2"
>
  <h3 class="text-xl font-semibold mb-4">Project Timeline</h3>
  {#if entries.length > 0}
    <div class="flex flex-col gap-2 max-h-96 overflow-y-auto">
      {#each entries as [week, stats]}
        {@const total = Object.values(stats).reduce((a, v) => a + (v || 0), 0)}
        <div class="flex items-center gap-3">
          <div class="w-28 text-sm text-muted">{week}</div>
          <div class="flex-1 bg-darkless rounded h-3 overflow-hidden">
            <div class="flex h-3 w-full">
              {#each Object.entries(stats) as [project, seconds]}
                <div
                  class="h-3 bg-primary/80"
                  style={`width:${percentOf(seconds, total)}%`}
                  title={`${project}: ${secondsToDisplay(seconds)}`}
                ></div>
              {/each}
            </div>
          </div>
          <div class="w-16 text-sm text-muted text-right">
            {secondsToDisplay(total)}
          </div>
        </div>
      {/each}
    </div>
  {:else}
    <p class="text-muted">No timeline data.</p>
  {/if}
</div>
