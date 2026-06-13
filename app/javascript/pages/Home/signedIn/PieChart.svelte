<script lang="ts">
  import { onMount } from "svelte";
  // @ts-expect-error d3-shape is present via LayerChart, but this app does not ship its type declarations.
  import { arc as d3arc, pie as d3pie } from "d3-shape";
  import { PieChart } from "layerchart";
  import { secondsToDisplay, CHART_COLORS as FALLBACK_COLORS } from "./utils";

  type ChartDatum = { name: string; value: number };

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
  onMount(() => (hasMounted = true));

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

  const staticPlotClass = $derived(
    legendPadding <= 42
      ? "bottom-[42px]"
      : legendPadding <= 60
        ? "bottom-[60px]"
        : legendPadding <= 78
          ? "bottom-[78px]"
          : "bottom-[96px]",
  );

  const colorForIndex = (i: number) => colors[i % colors.length];

  const staticArcs = $derived.by(() => {
    const arc = d3arc().innerRadius(0).outerRadius(50);
    return d3pie<ChartDatum>()
      .value((d: ChartDatum) => d.value)(data)
      .map((a: { data: ChartDatum }) => ({
        path: arc(a) || "",
        color: colorForIndex(data.indexOf(a.data)),
      }));
  });

  const handleChartResize = ({
    containerHeight,
  }: {
    containerHeight: number;
  }) => {
    if (containerHeight > 100) interactiveReady = true;
  };

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
            key="name"
            value="value"
            cRange={colors}
            legend={true}
            padding={{ bottom: legendPadding }}
            onresize={handleChartResize}
            props={{
              legend: {
                classes: {
                  root: "w-full px-2",
                  swatches: "flex-wrap justify-center",
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
          <div
            class="absolute inset-x-0 top-0 flex items-center justify-center {staticPlotClass}"
          >
            <svg
              class="h-full w-full overflow-visible"
              viewBox="0 0 100 100"
              preserveAspectRatio="xMidYMid meet"
              role="figure"
              aria-label={title}
            >
              <g transform="translate(50, 50)">
                {#each staticArcs as arc}
                  <path d={arc.path} fill={arc.color} stroke="none" />
                {/each}
              </g>
            </svg>
          </div>

          <div
            class="absolute bottom-0 left-1/2 z-[1] inline-block w-full -translate-x-1/2 px-2"
          >
            <div class="flex flex-wrap justify-center gap-x-4 gap-y-1">
              {#each data as item, i}
                <button class="flex cursor-auto gap-1">
                  <div
                    class="h-4 w-4 rounded-full"
                    style:background-color={colorForIndex(i)}
                  ></div>
                  <div
                    class="whitespace-nowrap text-xs text-surface-content/70"
                  >
                    {item.name}
                  </div>
                </button>
              {/each}
            </div>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</div>
