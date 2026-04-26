<script lang="ts">
  import { onMount } from "svelte";
  import { PieChart } from "layerchart";
  import { secondsToDisplay } from "./utils";

  type ChartDatum = { name: string; value: number };
  type StaticArc = {
    data: ChartDatum;
    startAngle: number;
    endAngle: number;
  };

  function computePieArcs(entries: ChartDatum[]): StaticArc[] {
    const arcs = new Array<StaticArc>(entries.length);
    const indices = entries.map((_, index) => index);
    const fullAngle = Math.PI * 2;
    const total = entries.reduce(
      (sum, entry) => sum + (entry.value > 0 ? entry.value : 0),
      0,
    );
    const anglePerValue = total > 0 ? fullAngle / total : 0;

    indices.sort((left, right) => entries[right].value - entries[left].value);

    let startAngle = 0;

    for (const index of indices) {
      const value = entries[index].value > 0 ? entries[index].value : 0;
      const endAngle = startAngle + value * anglePerValue;

      arcs[index] = {
        data: entries[index],
        startAngle,
        endAngle,
      };
      startAngle = endAngle;
    }

    return arcs;
  }

  let mounted = $state(false);
  onMount(() => {
    mounted = true;
  });

  let {
    title,
    stats,
    colorMap = {},
  }: {
    title: string;
    stats: Record<string, number>;
    colorMap?: Record<string, string>;
  } = $props();

  const FALLBACK_COLORS = [
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
    Object.entries(stats).map(([name, value]) => ({
      name,
      value,
    })) as ChartDatum[],
  );

  const colors = $derived.by(() => {
    if (Object.keys(colorMap).length > 0) {
      let fallbackIdx = 0;
      return data.map(
        (d) =>
          colorMap[d.name] ||
          FALLBACK_COLORS[fallbackIdx++ % FALLBACK_COLORS.length],
      );
    }
    return FALLBACK_COLORS;
  });

  const legendItems = $derived.by(() =>
    data.map((entry, index) => ({
      ...entry,
      color: colors[index % colors.length],
    })),
  );

  const staticGradient = $derived.by(() => {
    const colorByName = new Map(
      legendItems.map((entry) => [entry.name, entry.color]),
    );
    const arcs = computePieArcs(data)
      .filter((arc) => arc.endAngle > arc.startAngle)
      .sort((a, b) => a.startAngle - b.startAngle);

    if (arcs.length === 0) {
      return "";
    }

    return `conic-gradient(${arcs
      .map((arc) => {
        const color = colorByName.get(arc.data.name) || FALLBACK_COLORS[0];
        const start = (arc.startAngle * 180) / Math.PI;
        const end = (arc.endAngle * 180) / Math.PI;

        return `${color} ${start}deg ${end}deg`;
      })
      .join(", ")})`;
  });

  const legendClasses = {
    root: "w-full px-2",
    swatches: "flex-wrap justify-center",
    label: "text-xs text-surface-content/70",
  };

  const legendRows = $derived(Math.max(1, Math.ceil(data.length / 4)));
  const legendPadding = $derived(Math.min(96, 24 + legendRows * 18));

  const formatDuration = (value: number | null | undefined) =>
    secondsToDisplay(value ?? 0);
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col h-full"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">{title}</h2>
  <div
    class="relative flex-1 w-full chart-container flex items-center justify-center"
    style="min-height: 330px;"
  >
    {#if data.length > 0}
      {#if mounted}
        <PieChart
          {data}
          key="name"
          value="value"
          cRange={colors}
          legend={true}
          padding={{ bottom: legendPadding }}
          props={{
            legend: { classes: legendClasses },
            tooltip: { item: { format: formatDuration } },
          }}
        />
      {:else}
        <div
          class="pointer-events-none relative h-full w-full"
          style={`--legend-padding: ${legendPadding}px;`}
        >
          <div class="static-pie-area">
            <div
              class="static-pie"
              style:background-image={staticGradient || undefined}
            ></div>
          </div>

          <div
            class={`inline-block z-[1] absolute bottom-0 left-1/2 -translate-x-1/2 ${legendClasses.root}`}
          >
            <div class={`flex gap-x-4 gap-y-1 ${legendClasses.swatches}`}>
              {#each legendItems as item}
                <div class="flex gap-1">
                  <div
                    class="h-4 w-4 rounded-full"
                    style:background-color={item.color}
                  ></div>
                  <div
                    class={`text-xs text-surface-content whitespace-nowrap ${legendClasses.label}`}
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

<style>
  .static-pie-area {
    height: calc(100% - var(--legend-padding));
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .static-pie {
    height: 100%;
    width: auto;
    max-width: 100%;
    max-height: 100%;
    aspect-ratio: 1;
    border-radius: 9999px;
    flex: none;
  }

  .chart-container :global(svg) {
    max-width: 100%;
    height: auto;
  }
</style>
