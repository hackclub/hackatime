<script lang="ts">
  import { arc as d3Arc, pie as d3Pie, type PieArcDatum } from "d3-shape";
  import Button from "../../../components/Button.svelte";
  import { secondsToDisplay, CHART_COLORS as FALLBACK_COLORS } from "./utils";

  type ChartDatum = { name: string; value: number };

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

  let selectedName = $state<string | null>(null);
  let highlightedName = $state<string | null>(null);
  let tooltip = $state<{
    datum: ChartDatum;
    color: string;
    x: number;
    y: number;
  } | null>(null);

  const colorFor = (datum: ChartDatum) =>
    colors[data.findIndex((item) => item.name === datum.name) % colors.length];

  const visibleData = $derived(
    selectedName ? data.filter((datum) => datum.name === selectedName) : data,
  );

  const arcs = $derived.by(() => {
    const radius = Math.min(CHART_WIDTH, CHART_HEIGHT - legendPadding) / 2;
    const arc = d3Arc<PieArcDatum<ChartDatum>>()
      .innerRadius(0)
      .outerRadius(radius);

    return d3Pie<ChartDatum>()
      .value((datum) => datum.value)(visibleData)
      .map((datum) => ({
        datum: datum.data,
        color: colorFor(datum.data),
        path: arc(datum) ?? "",
      }));
  });

  $effect(() => {
    if (selectedName && !data.some((datum) => datum.name === selectedName)) {
      selectedName = null;
    }
  });

  const tooltipPosition = (event: PointerEvent | FocusEvent) => {
    if (event instanceof PointerEvent) {
      return {
        x: Math.min(event.clientX + 10, window.innerWidth - 150),
        y: Math.min(event.clientY + 10, window.innerHeight - 50),
      };
    }

    const rect = (
      event.currentTarget as SVGPathElement
    ).getBoundingClientRect();
    return {
      x: rect.left + rect.width / 2 + 10,
      y: rect.top + rect.height / 2,
    };
  };

  const showTooltip = (
    event: PointerEvent | FocusEvent,
    datum: ChartDatum,
    color: string,
  ) => {
    highlightedName = datum.name;
    tooltip = { datum, color, ...tooltipPosition(event) };
  };

  const hideTooltip = () => {
    highlightedName = null;
    tooltip = null;
  };

  const toggleSelection = (name: string) => {
    selectedName = selectedName === name ? null : name;
    hideTooltip();
  };
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex min-w-0 flex-col h-full"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">{title}</h2>
  <div
    class="hackatime-pie-chart relative h-[260px] min-w-0 sm:h-[290px] lg:h-[330px]"
  >
    {#if data.length > 0}
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
          {#each arcs as arc (arc.datum.name)}
            <path
              data-pie-slice={arc.datum.name}
              d={arc.path}
              fill={arc.color}
              opacity={highlightedName === null ||
              highlightedName === arc.datum.name
                ? 1
                : 0.5}
              role="img"
              aria-label={`${arc.datum.name}: ${secondsToDisplay(arc.datum.value)}`}
              onpointerenter={(event) =>
                showTooltip(event, arc.datum, arc.color)}
              onpointermove={(event) =>
                showTooltip(event, arc.datum, arc.color)}
              onpointerdown={(event) =>
                showTooltip(event, arc.datum, arc.color)}
              onpointerleave={hideTooltip}
              onpointercancel={hideTooltip}
            />
          {/each}
        </g>
      </svg>

      <div
        data-pie-legend
        class="absolute bottom-0 left-1/2 flex w-full -translate-x-1/2 flex-wrap items-center justify-center gap-x-4 gap-y-1 px-2"
      >
        {#each data as datum}
          <Button
            unstyled
            class={`flex items-center gap-1 whitespace-nowrap text-xs text-surface-content/70 ${selectedName !== null && selectedName !== datum.name ? "opacity-30" : ""}`}
            aria-pressed={selectedName === datum.name}
            aria-label={`${datum.name}: ${secondsToDisplay(datum.value)}`}
            onclick={() => toggleSelection(datum.name)}
            onfocus={(event: FocusEvent) =>
              showTooltip(event, datum, colorFor(datum))}
            onblur={hideTooltip}
          >
            <span
              class="h-4 w-4 shrink-0 rounded-full"
              style:background-color={colorFor(datum)}
            ></span>
            <span>{datum.name}</span>
          </Button>
        {/each}
      </div>
    {/if}
  </div>
</div>

{#if tooltip}
  <div
    class="pointer-events-none fixed z-50 select-none"
    style:left={`${tooltip.x}px`}
    style:top={`${tooltip.y}px`}
    role="tooltip"
  >
    <div
      class="lc-tooltip-container flex items-center gap-2 rounded-sm px-2 py-1 text-sm leading-5 shadow-sm backdrop-blur-[2px]"
      data-variant="default"
    >
      <span
        class="h-2 w-2 shrink-0 rounded-full"
        style:background-color={tooltip.color}
      ></span>
      <span class="text-surface-content/75">{tooltip.datum.name}</span>
      <span class="tabular-nums">
        {secondsToDisplay(tooltip.datum.value)}
      </span>
    </div>
  </div>
{/if}
