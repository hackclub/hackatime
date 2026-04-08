<script lang="ts">
  import { BarChart } from "layerchart";
  import { secondsToDisplay, secondsToCompactDisplay } from "../../../utils";

  let {
    weeklyStats,
  }: {
    weeklyStats: Record<string, Record<string, number>>;
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

  // the duplication here is intentional.
  function formatYAxis(value: number): string {
    return secondsToCompactDisplay(value);
  }

  function formatDuration(value: number): string {
    return secondsToDisplay(value);
  }
</script>

<div
  class="bg-dark/50 border border-surface-200 rounded-xl p-6 flex flex-col min-h-[400px]"
>
  <h2 class="mb-4 text-lg font-semibold text-surface-content/90">
    Project Timeline
  </h2>
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
          tooltip: { item: { format: formatDuration } },
        }}
      />
    </div>
  {/if}
</div>
