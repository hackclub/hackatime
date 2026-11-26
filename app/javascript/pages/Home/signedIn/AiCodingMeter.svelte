<script lang="ts">
  import { secondsToDisplay } from "./utils";

  let { stats }: { stats: Record<string, number> } = $props();

  const PERCENT_WIDTH_CLASSES = [
    "w-[0%]",
    "w-[1%]",
    "w-[2%]",
    "w-[3%]",
    "w-[4%]",
    "w-[5%]",
    "w-[6%]",
    "w-[7%]",
    "w-[8%]",
    "w-[9%]",
    "w-[10%]",
    "w-[11%]",
    "w-[12%]",
    "w-[13%]",
    "w-[14%]",
    "w-[15%]",
    "w-[16%]",
    "w-[17%]",
    "w-[18%]",
    "w-[19%]",
    "w-[20%]",
    "w-[21%]",
    "w-[22%]",
    "w-[23%]",
    "w-[24%]",
    "w-[25%]",
    "w-[26%]",
    "w-[27%]",
    "w-[28%]",
    "w-[29%]",
    "w-[30%]",
    "w-[31%]",
    "w-[32%]",
    "w-[33%]",
    "w-[34%]",
    "w-[35%]",
    "w-[36%]",
    "w-[37%]",
    "w-[38%]",
    "w-[39%]",
    "w-[40%]",
    "w-[41%]",
    "w-[42%]",
    "w-[43%]",
    "w-[44%]",
    "w-[45%]",
    "w-[46%]",
    "w-[47%]",
    "w-[48%]",
    "w-[49%]",
    "w-[50%]",
    "w-[51%]",
    "w-[52%]",
    "w-[53%]",
    "w-[54%]",
    "w-[55%]",
    "w-[56%]",
    "w-[57%]",
    "w-[58%]",
    "w-[59%]",
    "w-[60%]",
    "w-[61%]",
    "w-[62%]",
    "w-[63%]",
    "w-[64%]",
    "w-[65%]",
    "w-[66%]",
    "w-[67%]",
    "w-[68%]",
    "w-[69%]",
    "w-[70%]",
    "w-[71%]",
    "w-[72%]",
    "w-[73%]",
    "w-[74%]",
    "w-[75%]",
    "w-[76%]",
    "w-[77%]",
    "w-[78%]",
    "w-[79%]",
    "w-[80%]",
    "w-[81%]",
    "w-[82%]",
    "w-[83%]",
    "w-[84%]",
    "w-[85%]",
    "w-[86%]",
    "w-[87%]",
    "w-[88%]",
    "w-[89%]",
    "w-[90%]",
    "w-[91%]",
    "w-[92%]",
    "w-[93%]",
    "w-[94%]",
    "w-[95%]",
    "w-[96%]",
    "w-[97%]",
    "w-[98%]",
    "w-[99%]",
    "w-[100%]",
  ] as const;

  function percentWidthClass(percent: number): string {
    return PERCENT_WIDTH_CLASSES[
      Math.min(100, Math.max(0, Math.round(percent)))
    ];
  }

  const aiSeconds = $derived(stats["ai coding"] || 0);
  const struggleSeconds = $derived(stats["struggle point time"] || 0);
  const humanSeconds = $derived(stats.coding || 0);
  const hasStruggle = $derived(struggleSeconds > 0);
  const totalSeconds = $derived(aiSeconds + struggleSeconds + humanSeconds);
  const aiPercent = $derived(
    totalSeconds > 0 ? Math.round((aiSeconds / totalSeconds) * 100) : 0,
  );
  const strugglePercent = $derived(
    totalSeconds > 0 ? Math.round((struggleSeconds / totalSeconds) * 100) : 0,
  );
  const humanPercent = $derived(
    totalSeconds > 0 ? Math.max(0, 100 - aiPercent - strugglePercent) : 0,
  );
</script>

<section
  class="flex min-h-64 flex-col rounded-2xl border border-surface-200 bg-dark p-4 sm:p-6"
>
  <div>
    <h3 class="text-lg font-semibold text-surface-content">
      {hasStruggle ? "Coding Breakdown" : "AI vs Human Coding"}
    </h3>
    <p class="text-sm text-surface-content/55">
      Based on coding category duration
    </p>
  </div>

  <div class="my-auto py-6">
    <div
      class="flex h-5 w-full overflow-hidden rounded-full bg-surface-200/35"
      role="figure"
      aria-label={hasStruggle
        ? `${aiPercent}% AI coding, ${strugglePercent}% struggle point time, and ${humanPercent}% human coding`
        : `${aiPercent}% AI coding and ${humanPercent}% human coding`}
    >
      {#if totalSeconds > 0}
        <div
          class={`h-full bg-primary transition-[width] duration-300 ease-out ${percentWidthClass(aiPercent)}`}
        ></div>
        {#if hasStruggle}
          <div
            class={`h-full bg-emerald-400 transition-[width] duration-300 ease-out ${percentWidthClass(strugglePercent)}`}
          ></div>
        {/if}
        <div
          class={`h-full bg-blue transition-[width] duration-300 ease-out ${percentWidthClass(humanPercent)}`}
        ></div>
      {/if}
    </div>

    <div
      class={`mt-5 grid gap-4 ${hasStruggle ? "grid-cols-3" : "grid-cols-2"}`}
    >
      <div>
        <div class="flex items-center gap-2">
          <span class="h-2.5 w-2.5 rounded-full bg-primary"></span>
          <span class="text-sm text-surface-content/60">AI Coding</span>
        </div>
        <p class="mt-1 text-xl font-semibold tabular-nums text-surface-content">
          {aiPercent}%
        </p>
        <p class="text-xs text-surface-content/45">
          {secondsToDisplay(aiSeconds)}
        </p>
      </div>

      {#if hasStruggle}
        <div class="text-center">
          <div class="flex items-center justify-center gap-2">
            <span class="h-2.5 w-2.5 rounded-full bg-emerald-400"></span>
            <span class="text-sm text-surface-content/60"
              >Struggle Point Time</span
            >
          </div>
          <p
            class="mt-1 text-xl font-semibold tabular-nums text-surface-content"
          >
            {strugglePercent}%
          </p>
          <p class="text-xs text-surface-content/45">
            {secondsToDisplay(struggleSeconds)}
          </p>
        </div>
      {/if}

      <div class="text-right">
        <div class="flex items-center justify-end gap-2">
          <span class="text-sm text-surface-content/60">Human Coding</span>
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
</section>
