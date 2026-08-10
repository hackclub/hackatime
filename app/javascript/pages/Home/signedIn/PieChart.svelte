<script lang="ts">
  import { PieChart } from "layerchart/svg";
  import { secondsToDisplay, CHART_COLORS as FALLBACK_COLORS } from "./utils";

  const CHART_WIDTH = 300;
  const CHART_HEIGHT = 300;

  let {
    title,
    stats,
    colorMap = {},
  }: {
    title: string;
    stats: Record<string, number>;
    colorMap?: Record<string, string>;
  } = $props();

  const data = $derived(
    Object.entries(stats).map(([name, value]) => ({ name, value })),
  );

  const colors = $derived.by(() => {
    if (!Object.keys(colorMap).length) return FALLBACK_COLORS;
    let idx = 0;
    return data.map(
      (d) =>
        colorMap[d.name] || FALLBACK_COLORS[idx++ % FALLBACK_COLORS.length],
    );
  });

  const legendPadding = $derived(
    Math.min(96, 24 + Math.max(1, Math.ceil(data.length / 4)) * 18),
  );

  const formatDuration = (v: number | null | undefined) =>
    secondsToDisplay(v ?? 0);
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col h-full"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">{title}</h2>
  <div class="h-[260px] sm:h-[290px] lg:h-[330px]">
    {#if data.length > 0}
      <PieChart
        {data}
        ssr={true}
        width={CHART_WIDTH}
        height={CHART_HEIGHT}
        class="hackatime-pie-chart"
        key="name"
        value="value"
        cRange={colors}
        legend={true}
        padding={{ bottom: legendPadding }}
        props={{
          svg: {
            class: "h-full w-full",
            role: "img",
            "aria-label": title,
            viewBox: `0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`,
            preserveAspectRatio: "xMidYMid meet",
          },
          legend: {
            classes: {
              root: "w-full px-2",
              items: "flex-wrap justify-center",
              label: "text-xs text-surface-content/70",
            },
          },
          tooltip: { item: { format: formatDuration } },
        }}
      />
    {/if}
  </div>
</div>
