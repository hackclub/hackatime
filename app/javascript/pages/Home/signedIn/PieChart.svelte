<script lang="ts">
  import { onMount } from "svelte";
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

  let hasMounted = $state(false);
  let interactiveReady = $state(false);

  onMount(() => {
    hasMounted = true;
    requestAnimationFrame(() => {
      requestAnimationFrame(() => (interactiveReady = true));
    });
  });

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

  const staticArcs = $derived.by(() => {
    const radius = (CHART_HEIGHT - legendPadding) / 2;
    const total = data.reduce((sum, item) => sum + Math.max(0, item.value), 0);
    if (total === 0) return [];

    const arcs = Array<{ path: string; color: string }>(data.length);
    let angle = 0;
    const indices = data
      .map((_, index) => index)
      .sort((a, b) => data[b].value - data[a].value || a - b);

    for (const index of indices) {
      const start = angle;
      const sweep = (Math.max(0, data[index].value) / total) * Math.PI * 2;
      const end = start + sweep;
      angle = end;

      const startX = radius * Math.cos(start - Math.PI / 2);
      const startY = radius * Math.sin(start - Math.PI / 2);
      const endX = radius * Math.cos(end - Math.PI / 2);
      const endY = radius * Math.sin(end - Math.PI / 2);
      const path =
        sweep >= Math.PI * 2 - Number.EPSILON
          ? `M0,${-radius} A${radius},${radius} 0 1 1 0,${radius} A${radius},${radius} 0 1 1 0,${-radius} Z`
          : `M0,0 L${startX},${startY} A${radius},${radius} 0 ${sweep > Math.PI ? 1 : 0} 1 ${endX},${endY} Z`;
      arcs[index] = { path, color: colors[index % colors.length] };
    }

    return arcs;
  });

  const formatDuration = (v: number | null | undefined) =>
    secondsToDisplay(v ?? 0);
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col h-full"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">{title}</h2>
  <div class="relative h-[260px] sm:h-[290px] lg:h-[330px]">
    {#if data.length > 0}
      {#if hasMounted}
        <div class="absolute inset-0" class:invisible={!interactiveReady}>
          <PieChart
            {data}
            width={CHART_WIDTH}
            height={CHART_HEIGHT}
            class="hackatime-pie-chart"
            key="name"
            value="value"
            cRange={colors}
            legend={true}
            motion="none"
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
        </div>
      {/if}

      {#if !interactiveReady}
        <div class="absolute inset-0">
          <svg
            class="h-full w-full"
            viewBox={`0 0 ${CHART_WIDTH} ${CHART_HEIGHT}`}
            preserveAspectRatio="xMidYMid meet"
            role="img"
            aria-label={title}
          >
            <g
              transform={`translate(${CHART_WIDTH / 2}, ${(CHART_HEIGHT - legendPadding) / 2})`}
            >
              {#each staticArcs as arc}
                <path d={arc.path} fill={arc.color} stroke="none" />
              {/each}
            </g>
          </svg>

          <div
            class="absolute bottom-0 left-1/2 z-[1] inline-block w-full -translate-x-1/2 px-2"
          >
            <div class="flex flex-wrap justify-center gap-x-4 gap-y-1">
              {#each data as item, index}
                <div class="flex gap-1">
                  <div
                    class="h-4 w-4 rounded-full"
                    style:background-color={colors[index % colors.length]}
                  ></div>
                  <div
                    class="whitespace-nowrap text-xs text-surface-content/70"
                  >
                    {item.name}
                  </div>
                </div>
              {/each}
            </div>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</div>
