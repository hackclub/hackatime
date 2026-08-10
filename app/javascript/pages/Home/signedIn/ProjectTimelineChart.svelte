<script lang="ts">
  import { Chart, Rect, Tooltip } from "layerchart/svg";
  import {
    secondsToDisplay,
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

  const stackTop = (context: any, seriesKey: string, d: TimelineDatum) =>
    Math.max(...(context.series.getStackValue(seriesKey, d) ?? [0, 0]));

  const stackHeight = (context: any, seriesKey: string, d: TimelineDatum) => {
    const [start, end] = context.series.getStackValue(seriesKey, d) ?? [0, 0];
    return Math.abs(context.yScale(start) - context.yScale(end));
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
        bandPadding={0.4}
        series={chartSeries}
        seriesLayout="stack"
        tooltipContext={{ mode: "band" }}
        highlight={{ area: true }}
        padding={{ top: 4, right: 4, left: 20, bottom: 20 }}
        props={{
          xAxis: { tickSpacing: 48 },
          yAxis: { format: secondsToDisplay },
          tooltip: { root: { motion: "none" } },
        }}
      >
        {#snippet marks({ context })}
          {#each context.series.visibleSeries as series (series.key)}
            {@const seriesData = splitSeriesData(context, series.key)}
            {#if seriesData.square.length > 0}
              <Rect
                data={seriesData.square}
                x="week"
                y={(d) => stackTop(context, series.key, d)}
                width={() => context.xScale.bandwidth?.() ?? 0}
                height={(d) => stackHeight(context, series.key, d)}
                fill={series.color}
                stroke="black"
                strokeWidth={1}
                class="lc-bar lc-bars-bar"
              />
            {/if}
            {#if seriesData.rounded.length > 0}
              <Rect
                data={seriesData.rounded}
                x="week"
                y={(d) => stackTop(context, series.key, d)}
                width={() => context.xScale.bandwidth?.() ?? 0}
                height={(d) => stackHeight(context, series.key, d)}
                fill={series.color}
                stroke="black"
                strokeWidth={1}
                corners={[4, 4, 0, 0]}
                class="lc-bar lc-bars-bar"
              />
            {/if}
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
