<script lang="ts">
  import { tickIncrement, ticks } from "d3-array";
  import { fade } from "svelte/transition";
  import {
    secondsToDisplay,
    secondsToCompactDisplay,
    formatUtcDayMonth,
    formatWeekRange,
  } from "../../../utils";
  import { CHART_COLORS as PIE_COLORS } from "./utils";

  let {
    weeklyStats,
  }: {
    weeklyStats: Record<string, Record<string, number>>;
  } = $props();

  const MAX_PROJECT_SERIES = 16;
  const OTHER_KEY = "__other_projects__";
  const BAND_PADDING = 0.4;
  const PADDING = { top: 4, right: 4, bottom: 20, left: 20 };

  const sortedWeeks = $derived(Object.keys(weeklyStats).sort());

  const allProjects = $derived.by(() => {
    const totals = new Map<string, number>();
    for (const week of Object.values(weeklyStats))
      for (const [p, s] of Object.entries(week))
        totals.set(p, (totals.get(p) || 0) + s);
    return [...totals.entries()].sort((a, b) => b[1] - a[1]).map(([n]) => n);
  });

  const chartProjects = $derived(allProjects.slice(0, MAX_PROJECT_SERIES));
  const otherProjects = $derived(allProjects.slice(MAX_PROJECT_SERIES));
  const includeOther = $derived(otherProjects.length > 0);

  const data = $derived(
    sortedWeeks.map((week) => {
      const row: Record<string, string | number> = {
        week: formatUtcDayMonth(week),
        weekRange: formatWeekRange(week),
      };
      const ws = weeklyStats[week] || {};
      for (const p of chartProjects) row[p] = ws[p] || 0;
      if (includeOther)
        row[OTHER_KEY] = otherProjects.reduce((t, p) => t + (ws[p] || 0), 0);
      return row;
    }),
  );

  const chartSeries = $derived([
    ...chartProjects.map((p, i) => ({
      key: p,
      label: p,
      color: PIE_COLORS[i % PIE_COLORS.length],
    })),
    ...(includeOther
      ? [{ key: OTHER_KEY, label: "Other projects", color: "#9ca3af" }]
      : []),
  ]);

  type TimelineDatum = Record<string, string | number>;
  const getVal = (d: TimelineDatum | null | undefined, k: string) =>
    typeof d?.[k] === "number" ? (d[k] as number) : 0;

  const maxWeekTotal = $derived(
    Math.max(
      0,
      ...data.map((row) =>
        chartSeries.reduce(
          (total, series) => total + getVal(row, series.key),
          0,
        ),
      ),
    ),
  );

  const niceUpperBound = (value: number) => {
    if (value === 0) return 1;

    let start = 0;
    let stop = value;
    let previousStep: number | undefined;

    for (let i = 0; i < 10; i += 1) {
      const step = tickIncrement(start, stop, 10);
      if (step === previousStep) return stop;
      if (step > 0) {
        start = Math.floor(start / step) * step;
        stop = Math.ceil(stop / step) * step;
      } else if (step < 0) {
        start = Math.ceil(start * step) / step;
        stop = Math.floor(stop * step) / step;
      } else {
        break;
      }
      previousStep = step;
    }

    return stop;
  };

  let container = $state<HTMLDivElement>();
  let containerWidth = $state(0);
  let containerHeight = $state(0);
  let hoveredIndex = $state<number | null>(null);
  let tooltipData = $state<TimelineDatum | null>(null);
  let pointerX = $state(0);
  let pointerY = $state(0);
  let tooltipWidth = $state(0);
  let tooltipHeight = $state(0);
  let hideTimeout: ReturnType<typeof setTimeout> | undefined;

  const width = $derived(
    Math.max(0, containerWidth - PADDING.left - PADDING.right),
  );
  const height = $derived(
    Math.max(0, containerHeight - PADDING.top - PADDING.bottom),
  );
  const bandStep = $derived(
    data.length > 0
      ? width / Math.max(1, data.length - BAND_PADDING + BAND_PADDING * 2)
      : 0,
  );
  const bandwidth = $derived(bandStep * (1 - BAND_PADDING));
  const bandStart = $derived(
    (width - bandStep * (data.length - BAND_PADDING)) / 2,
  );
  const yMax = $derived(niceUpperBound(maxWeekTotal));
  const yTicks = $derived(ticks(0, yMax, 5));
  const xPosition = (index: number) => bandStart + index * bandStep;
  const yPosition = (value: number) => height * (1 - value / yMax);

  const stackBounds = (seriesKey: string, row: TimelineDatum) => {
    let start = 0;
    for (const series of chartSeries) {
      const end = start + getVal(row, series.key);
      if (series.key === seriesKey) return [start, end] as const;
      start = end;
    }
    return [0, 0] as const;
  };

  const roundedTopRectPath = (
    x: number,
    y: number,
    width: number,
    height: number,
  ) => {
    const radius = Math.min(4, width / 2, height / 2);
    return [
      `M${x + radius},${y}`,
      `h${width - radius * 2}`,
      `a${radius},${radius} 0 0 1 ${radius},${radius}`,
      `v${height - radius}`,
      `h${-width}`,
      `v${-(height - radius)}`,
      `a${radius},${radius} 0 0 1 ${radius},${-radius}`,
      "z",
    ].join(" ");
  };

  const isTopSeries = (seriesKey: string, row: TimelineDatum) =>
    [...chartSeries].reverse().find((series) => getVal(row, series.key) > 0)
      ?.key === seriesKey;

  const showTooltip = (
    event: PointerEvent,
    row: TimelineDatum,
    index: number,
  ) => {
    if (hideTimeout) clearTimeout(hideTimeout);
    hoveredIndex = index;
    tooltipData = row;
    pointerX = event.clientX;
    pointerY = event.clientY;
  };

  const hideTooltip = () => {
    if (hideTimeout) clearTimeout(hideTimeout);
    hideTimeout = setTimeout(() => {
      hideTimeout = undefined;
      hoveredIndex = null;
      tooltipData = null;
    });
  };

  $effect(() => {
    data;

    if (hideTimeout) clearTimeout(hideTimeout);
    hideTimeout = undefined;
    hoveredIndex = null;
    tooltipData = null;

    return () => {
      if (hideTimeout) clearTimeout(hideTimeout);
    };
  });

  const tooltipItems = $derived(
    tooltipData
      ? [...chartSeries]
          .reverse()
          .filter((series) => getVal(tooltipData, series.key) > 0)
      : [],
  );
  const tooltipTotal = $derived(
    tooltipItems.reduce(
      (total, series) => total + getVal(tooltipData, series.key),
      0,
    ),
  );
  const tooltipPosition = $derived.by(() => {
    containerWidth;
    if (!container) return { left: pointerX + 10, top: pointerY + 10 };

    const bounds = container.getBoundingClientRect();
    let left = pointerX + 10;
    let top = pointerY + 10;

    if (left + tooltipWidth > bounds.right) left = pointerX - 10 - tooltipWidth;
    if (left < bounds.left + PADDING.left) left = pointerX + 10;
    if (top + tooltipHeight > bounds.bottom)
      top = pointerY - 10 - tooltipHeight;
    if (top < bounds.top + PADDING.top) top = pointerY + 10;

    return { left, top };
  });
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col min-h-[400px]"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">
    Project Timeline
  </h2>
  {#if data.length > 0 && chartSeries.length > 0}
    <div class="h-[350px]">
      {#if typeof window !== "undefined"}
        <!-- svelte-ignore a11y_no_static_element_interactions -->
        <div
          bind:this={container}
          bind:clientWidth={containerWidth}
          bind:clientHeight={containerHeight}
          class="native-chart relative h-full w-full"
          onpointerleave={hideTooltip}
          onpointercancel={hideTooltip}
        >
          {#if width > 0 && height > 0}
            <svg
              width={containerWidth}
              height={containerHeight}
              class="lc-layout-svg"
              role="figure"
              aria-label="Stacked project coding time by week"
              style="touch-action: pan-y"
            >
              <g transform={`translate(${PADDING.left}, ${PADDING.top})`}>
                <g class="lc-group-g lc-grid lc-grid-y">
                  {#each yTicks as tick (tick)}
                    <line
                      x1={0}
                      x2={width}
                      y1={yPosition(tick)}
                      y2={yPosition(tick)}
                      class="lc-line lc-grid-y-rule lc-grid-y-line stroke-surface-content/10"
                    />
                  {/each}
                </g>
                {#if hoveredIndex !== null}
                  <rect
                    x={xPosition(hoveredIndex) - (BAND_PADDING * bandStep) / 2}
                    y={0}
                    width={bandStep}
                    {height}
                    class="lc-rect lc-highlight-area"
                  />
                {/if}
                <g class="lc-group-g lc-axis placement-left">
                  {#each yTicks as tick (tick)}
                    <g class="lc-group-g lc-axis-tick-group">
                      <line
                        x1={-4}
                        x2={0}
                        y1={yPosition(tick)}
                        y2={yPosition(tick)}
                        class="lc-line lc-axis-tick stroke-surface-content/50"
                      />
                      <text
                        x={-4}
                        y={yPosition(tick)}
                        dy="3.5px"
                        text-anchor="end"
                        class="lc-text lc-axis-tick-label text-[10px] stroke-surface-100 [stroke-width:2px] font-light [paint-order:stroke]"
                      >
                        <tspan class="lc-text-tspan"
                          >{secondsToCompactDisplay(tick)}</tspan
                        >
                      </text>
                    </g>
                  {/each}
                </g>
                <g class="lc-group-g lc-axis placement-bottom">
                  {#each data as row, index (row.week)}
                    {#if width >= 400 || index % 3 === 0}
                      {@const x = xPosition(index) + bandwidth / 2}
                      <g class="lc-group-g lc-axis-tick-group">
                        <line
                          x1={x}
                          x2={x}
                          y1={height}
                          y2={height + 4}
                          class="lc-line lc-axis-tick stroke-surface-content/50"
                        />
                        <text
                          {x}
                          y={height + 4}
                          dy="11px"
                          text-anchor="middle"
                          class="lc-text lc-axis-tick-label text-[10px] stroke-surface-100 [stroke-width:2px] font-light [paint-order:stroke]"
                        >
                          <tspan class="lc-text-tspan">{row.week}</tspan>
                        </text>
                      </g>
                    {/if}
                  {/each}
                </g>
                {#each chartSeries as series (series.key)}
                  {#each data as row, index (row.week)}
                    {@const value = getVal(row, series.key)}
                    {#if value > 0}
                      {@const [start, end] = stackBounds(series.key, row)}
                      {@const x = xPosition(index)}
                      {@const y = yPosition(end)}
                      {@const barHeight = Math.abs(
                        yPosition(start) - yPosition(end),
                      )}
                      {#if isTopSeries(series.key, row)}
                        <path
                          d={roundedTopRectPath(x, y, bandwidth, barHeight)}
                          fill={series.color}
                          stroke="black"
                          stroke-width={1}
                          class="lc-rect lc-bar lc-bars-bar"
                        />
                      {:else}
                        <rect
                          {x}
                          {y}
                          width={bandwidth}
                          height={barHeight}
                          fill={series.color}
                          stroke="black"
                          stroke-width={1}
                          class="lc-rect lc-bar lc-bars-bar"
                        />
                      {/if}
                    {/if}
                  {/each}
                {/each}
                <g class="lc-group-g lc-rule-g">
                  <line
                    x1={0}
                    x2={width}
                    y1={yPosition(0)}
                    y2={yPosition(0)}
                    class="lc-line lc-rule-y-line stroke-surface-content/50"
                  />
                </g>
                {#each data as row, index (row.week)}
                  <!-- svelte-ignore a11y_no_static_element_interactions -->
                  <rect
                    x={xPosition(index) - (BAND_PADDING * bandStep) / 2}
                    y={0}
                    width={bandStep}
                    {height}
                    class="lc-tooltip-rect"
                    data-week={row.week}
                    onpointerenter={(event) => showTooltip(event, row, index)}
                    onpointermove={(event) => showTooltip(event, row, index)}
                    onpointerleave={hideTooltip}
                    onpointerdown={(event) => {
                      const target = event.currentTarget;
                      if (target.hasPointerCapture(event.pointerId))
                        target.releasePointerCapture(event.pointerId);
                    }}
                  />
                {/each}
              </g>
            </svg>
          {/if}

          {#if tooltipData}
            <div
              bind:clientWidth={tooltipWidth}
              bind:clientHeight={tooltipHeight}
              class="lc-tooltip-root disablePointerEvents portaled"
              style:top={`${tooltipPosition.top}px`}
              style:left={`${tooltipPosition.left}px`}
              transition:fade={{ duration: 100 }}
            >
              <div class="lc-tooltip-container" data-variant="default">
                <div class="lc-tooltip-content">
                  <div class="lc-tooltip-header">
                    {tooltipData.weekRange ?? tooltipData.week}
                  </div>
                  <div class="lc-tooltip-list">
                    {#each tooltipItems as series (series.key)}
                      <div class="lc-tooltip-item-root">
                        <div class="lc-tooltip-item-label label">
                          <div
                            class="lc-tooltip-item-color color"
                            style:--color={series.color}
                          ></div>
                          {series.label ?? series.key}
                        </div>
                        <div
                          class="lc-tooltip-item-value value"
                          data-align="right"
                        >
                          {secondsToDisplay(getVal(tooltipData, series.key))}
                        </div>
                      </div>
                    {/each}
                    {#if tooltipItems.length > 1}
                      <div class="lc-tooltip-separator"></div>
                      <div class="lc-tooltip-item-root">
                        <div class="lc-tooltip-item-label label">total</div>
                        <div
                          class="lc-tooltip-item-value value"
                          data-align="right"
                        >
                          {secondsToDisplay(tooltipTotal)}
                        </div>
                      </div>
                    {/if}
                  </div>
                </div>
              </div>
            </div>
          {/if}
        </div>
      {/if}
    </div>
  {/if}
</div>

<style>
  .native-chart,
  .native-chart :global(*) {
    box-sizing: border-box;
  }

  .native-chart {
    -webkit-user-select: none;
    user-select: none;
  }

  :where(.lc-layout-svg) {
    overflow: visible;
  }

  :where(.lc-text) {
    --fill-color: var(--color-surface-content, currentColor);
    --stroke-color: initial;
  }

  :where(.lc-layout-svg .lc-text):not([fill]) {
    color: var(--fill-color);
    fill: currentColor;
  }

  :where(.lc-highlight-area) {
    fill: color-mix(
      in oklab,
      var(--color-surface-content, currentColor) 5%,
      transparent
    );
  }

  :where(.lc-tooltip-rect) {
    fill: transparent;
  }

  :where(.lc-tooltip-root) {
    position: absolute;
    z-index: 50;
    user-select: none;
  }

  :where(.lc-tooltip-root.portaled) {
    position: fixed;
  }

  :where(.lc-tooltip-root.disablePointerEvents) {
    pointer-events: none;
  }

  :where(.lc-tooltip-container):not([data-variant="none"]) {
    height: 100%;
    padding: 4px 8px;
    border-radius: 0.25rem;
    font-size: 0.875rem;
    line-height: 1.25rem;
    box-shadow:
      0 2px 1px -1px hsl(0 0% 0% / 20%),
      0 1px 1px 0 hsl(0 0% 0% / 14%),
      0 1px 3px 0 hsl(0 0% 0% / 12%);
    backdrop-filter: blur(2px);
  }

  :where(.lc-tooltip-container)[data-variant="default"] {
    color: var(--color-surface-content, currentColor);
  }

  :where(.lc-tooltip-container)[data-variant="default"] :global(.label) {
    color: color-mix(
      in oklab,
      var(--color-surface-content, currentColor) 75%,
      transparent
    );
  }

  :where(.lc-tooltip-header) {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;
    padding-bottom: 4px;
    border-bottom: 1px solid
      color-mix(
        in oklab,
        var(--color-surface-content, currentColor) 20%,
        transparent
      );
    font-weight: 600;
    white-space: nowrap;
  }

  :where(.lc-tooltip-list) {
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: start;
    gap: 4px 8px;
  }

  :where(.lc-tooltip-item-root) {
    display: contents;
  }

  :where(.lc-tooltip-item-color) {
    display: inline-block;
    width: 8px;
    height: 8px;
    flex-shrink: 0;
    border-radius: 9999px;
    background-color: var(--color);
  }

  :where(.lc-tooltip-item-label) {
    display: flex;
    align-items: center;
    gap: 8px;
    white-space: nowrap;
  }

  :where(.lc-tooltip-item-value) {
    font-variant-numeric: tabular-nums;
  }

  :where(.lc-tooltip-item-value)[data-align="right"] {
    text-align: right;
  }

  :where(.lc-tooltip-separator) {
    grid-column: 1 / -1;
    height: 1px;
    margin-top: 4px;
    margin-bottom: 4px;
    border-radius: 4px;
    background-color: color-mix(
      in oklab,
      var(--color-surface-content, currentColor) 20%,
      transparent
    );
  }
</style>
