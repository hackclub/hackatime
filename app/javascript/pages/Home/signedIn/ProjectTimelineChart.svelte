<script lang="ts">
  import { BarChart, Tooltip } from "layerchart";

  let {
    weeklyStats,
  }: {
    weeklyStats: Record<string, Record<string, number>>;
  } = $props();

  const PIE_COLORS = [
    "#60a5fa", "#f472b6", "#fb923c", "#facc15", "#4ade80",
    "#2dd4bf", "#a78bfa", "#f87171", "#38bdf8", "#e879f9",
    "#34d399", "#fbbf24", "#818cf8", "#fb7185", "#22d3ee",
    "#a3e635", "#c084fc", "#f97316", "#14b8a6", "#8b5cf6",
  ];

  const sortedWeeks = $derived(Object.keys(weeklyStats).sort());

  const allProjects = $derived.by(() => {
    const projectTotals = new Map<string, number>();
    for (const weekData of Object.values(weeklyStats)) {
      for (const [project, seconds] of Object.entries(weekData)) {
        projectTotals.set(project, (projectTotals.get(project) || 0) + seconds);
      }
    }
    return Array.from(projectTotals.entries())
      .sort((a, b) => b[1] - a[1])
      .map(([name]) => name);
  });

  const data = $derived(
    sortedWeeks.map((week) => {
      const row: Record<string, string | number> = {
        week: new Date(week).toLocaleDateString("en-US", {
          month: "short",
          day: "numeric",
        }),
      };
      for (const project of allProjects) {
        row[project] = weeklyStats[week][project] || 0;
      }
      return row;
    }),
  );

  const series = $derived(
    allProjects.map((project, i) => ({
      key: project,
      label: project,
      color: PIE_COLORS[i % PIE_COLORS.length],
    })),
  );

  const chartPadding = $derived.by(() => ({
    top: 4,
    right: 4,
    left: 20,
    bottom: 20,
  }));

  function formatDuration(value: number): string {
    if (value === 0) return "0s";
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
  }

  function formatYAxis(value: number): string {
    if (value === 0) return "0s";
    const hours = Math.floor(value / 3600);
    const minutes = Math.floor((value % 3600) / 60);
    return hours > 0 ? `${hours}h` : `${minutes}m`;
  }

  type TimelineDatum = Record<string, string | number>;

  function getSeriesValue(datum: TimelineDatum | null | undefined, key: string): number {
    const value = datum?.[key];
    return typeof value === "number" ? value : 0;
  }
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col min-h-[400px]"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">Project Timeline</h2>
  {#if data.length > 0}
    <div class="h-[350px]">
      <BarChart
        {data}
        x="week"
        {series}
        seriesLayout="stack"
        padding={chartPadding}
        props={{
          yAxis: { format: formatYAxis },
        }}
      >
        <svelte:fragment slot="tooltip">
          <Tooltip.Root let:data>
            {#if data}
              <Tooltip.Header value={data.week} />
              <Tooltip.List>
                {@const seriesItems = [...series]
                  .reverse()
                  .filter((s) => getSeriesValue(data, s.key) > 0)}
                {#each seriesItems as s}
                  {@const value = getSeriesValue(data, s.key)}
                  <Tooltip.Item
                    label={s.label ?? s.key}
                    value={value}
                    color={s.color}
                    format={formatDuration}
                    valueAlign="right"
                  />
                {/each}
                {#if seriesItems.length > 1}
                  <Tooltip.Separator />
                  <Tooltip.Item
                    label="total"
                    value={seriesItems.reduce(
                      (total, s) => total + getSeriesValue(data, s.key),
                      0,
                    )}
                    format={formatDuration}
                    valueAlign="right"
                  />
                {/if}
              </Tooltip.List>
            {/if}
          </Tooltip.Root>
        </svelte:fragment>
      </BarChart>
    </div>
  {/if}
</div>
