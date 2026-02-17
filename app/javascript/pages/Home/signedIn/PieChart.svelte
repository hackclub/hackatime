<script lang="ts">
  import { PieChart } from "layerchart";
  import { secondsToDisplay } from "./utils";

  let {
    title,
    stats,
  }: {
    title: string;
    stats: Record<string, number>;
  } = $props();

  const PIE_COLORS = [
    "#60a5fa",
    "#f472b6",
    "#fb923c",
    "#facc15",
    "#4ade80",
    "#2dd4bf",
    "#a78bfa",
    "#f87171",
    "#38bdf8",
    "#e879f9",
    "#34d399",
    "#fbbf24",
    "#818cf8",
    "#fb7185",
    "#22d3ee",
    "#a3e635",
    "#c084fc",
    "#f97316",
    "#14b8a6",
    "#8b5cf6",
    "#ec4899",
    "#84cc16",
    "#06b6d4",
    "#d946ef",
    "#10b981",
  ];

  const data = $derived(
    Object.entries(stats).map(([name, value]) => ({ name, value })),
  );

  const legendClasses = {
    root: "w-full px-2",
    swatches: "flex-wrap justify-center",
    label: "text-xs text-surface-content/70",
  };

  const legendPadding = $derived.by(() => {
    const rows = Math.max(1, Math.ceil(data.length / 4));
    return Math.min(96, 24 + rows * 18);
  });

  const formatDuration = (value: number | null | undefined) =>
    secondsToDisplay(value ?? 0);
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col h-full"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">{title}</h2>
  <div class="h-[260px] sm:h-[280px] lg:h-[300px]">
    {#if data.length > 0}
      <PieChart
        {data}
        key="name"
        value="value"
        cRange={PIE_COLORS}
        legend={true}
        padding={{ bottom: legendPadding }}
        props={{
          legend: { classes: legendClasses },
          tooltip: { item: { format: formatDuration } },
        }}
      />
    {/if}
  </div>
</div>
