<script lang="ts">
  import { Chart, Tooltip } from "layerchart/svg";
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

  const splitSeriesData = (context: any, seriesKey: string) => {
    const square: TimelineDatum[] = [];
    const rounded: TimelineDatum[] = [];

    for (const row of data) {
      if (getVal(row, seriesKey) <= 0) continue;

      const topSeries = [...context.series.visibleSeries]
        .reverse()
        .find((series) => getVal(row, series.key) > 0);
      (topSeries?.key === seriesKey ? rounded : square).push(row);
    }

    return { square, rounded };
  };
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col min-h-[400px]"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">
    Project Timeline
  </h2>
  {#if data.length > 0 && chartSeries.length > 0}
    <div class="h-[350px]">
      <Chart
        {data}
        x="week"
        valueAxis="y"
        yDomain={[0, maxWeekTotal]}
        bandPadding={0.4}
        series={chartSeries}
        seriesLayout="stack"
        tooltipContext={{ mode: "band" }}
        highlight={{ area: true }}
        padding={{ top: 4, right: 4, left: 20, bottom: 20 }}
        props={{
          xAxis: { tickSpacing: 48 },
          yAxis: { format: secondsToCompactDisplay },
          tooltip: { root: { motion: "none" } },
        }}
      >
        {#snippet grid({ context })}
          <g class="lc-group-g lc-grid lc-grid-y">
            {#each (context.yScale as any).ticks(5) as tick (tick)}
              <line
                x1={0}
                x2={context.width}
                y1={context.yScale(tick)}
                y2={context.yScale(tick)}
                class="lc-line lc-grid-y-rule lc-grid-y-line stroke-surface-content/10"
              />
            {/each}
          </g>
        {/snippet}
        {#snippet axis({ context })}
          <g class="lc-group-g lc-axis placement-left">
            {#each (context.yScale as any).ticks(5) as tick (tick)}
              <g class="lc-group-g lc-axis-tick-group">
                <line
                  x1={-4}
                  x2={0}
                  y1={context.yScale(tick)}
                  y2={context.yScale(tick)}
                  class="lc-line lc-axis-tick stroke-surface-content/50"
                />
                <text
                  x={-4}
                  y={context.yScale(tick)}
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
            {#each context.xScale
              .domain()
              .filter((_, index) => context.width >= 400 || index % 3 === 0) as tick (tick)}
              {@const x =
                context.xScale(tick) + (context.xScale as any).bandwidth() / 2}
              <g class="lc-group-g lc-axis-tick-group">
                <line
                  x1={x}
                  x2={x}
                  y1={context.height}
                  y2={context.height + 4}
                  class="lc-line lc-axis-tick stroke-surface-content/50"
                />
                <text
                  {x}
                  y={context.height + 4}
                  dy="11px"
                  text-anchor="middle"
                  class="lc-text lc-axis-tick-label text-[10px] stroke-surface-100 [stroke-width:2px] font-light [paint-order:stroke]"
                >
                  <tspan class="lc-text-tspan">{tick}</tspan>
                </text>
              </g>
            {/each}
          </g>
        {/snippet}
        {#snippet rule({ context })}
          <g class="lc-group-g lc-rule-g">
            <line
              x1={0}
              x2={context.width}
              y1={context.yScale(0)}
              y2={context.yScale(0)}
              class="lc-line lc-rule-y-line stroke-surface-content/50"
            />
          </g>
        {/snippet}
        {#snippet marks({ context })}
          {#each context.series.visibleSeries as series (series.key)}
            {@const seriesData = splitSeriesData(context, series.key)}
            {#each seriesData.square as row (row.week)}
              {@const [start, end] = stackBounds(series.key, row)}
              <rect
                x={context.xScale(row.week)}
                y={context.yScale(end)}
                width={(context.xScale as any).bandwidth()}
                height={Math.abs(context.yScale(start) - context.yScale(end))}
                fill={series.color}
                stroke="black"
                stroke-width={1}
                class="lc-rect lc-bar lc-bars-bar"
              />
            {/each}
            {#each seriesData.rounded as row (row.week)}
              {@const [start, end] = stackBounds(series.key, row)}
              {@const x = context.xScale(row.week)}
              {@const y = context.yScale(end)}
              {@const width = (context.xScale as any).bandwidth()}
              {@const height = Math.abs(
                context.yScale(start) - context.yScale(end),
              )}
              <path
                d={roundedTopRectPath(x, y, width, height)}
                fill={series.color}
                stroke="black"
                stroke-width={1}
                class="lc-rect lc-bar lc-bars-bar"
              />
            {/each}
          {/each}
        {/snippet}
        {#snippet tooltip({ context })}
          <Tooltip.Root {context}>
            {#snippet children({ data })}
              {#if data}
                <Tooltip.Header value={data.weekRange ?? data.week} />
                <Tooltip.List>
                  {@const items = [...chartSeries]
                    .reverse()
                    .filter((s) => getVal(data, s.key) > 0)}
                  {#each items as s}
                    <Tooltip.Item
                      label={s.label ?? s.key}
                      value={getVal(data, s.key)}
                      color={s.color}
                      format={secondsToDisplay}
                      valueAlign="right"
                    />
                  {/each}
                  {#if items.length > 1}
                    <Tooltip.Separator />
                    <Tooltip.Item
                      label="total"
                      value={items.reduce((t, s) => t + getVal(data, s.key), 0)}
                      format={secondsToDisplay}
                      valueAlign="right"
                    />
                  {/if}
                </Tooltip.List>
              {/if}
            {/snippet}
          </Tooltip.Root>
        {/snippet}
      </Chart>
    </div>
  {/if}
</div>
