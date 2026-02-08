<script lang="ts">
  import { onMount, onDestroy } from "svelte";

  let {
    weeklyStats,
  }: {
    weeklyStats: Record<string, Record<string, number>>;
  } = $props();

  let canvas: HTMLCanvasElement;
  let chart: any = null;

  async function createChart() {
    if (chart) chart.destroy();

    const {
      Chart,
      BarController,
      BarElement,
      CategoryScale,
      LinearScale,
      Tooltip,
      Legend,
    } = await import("chart.js");
    Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend);

    const allProjects = new Set<string>();
    Object.values(weeklyStats).forEach((weekData) => {
      Object.keys(weekData).forEach((project) => allProjects.add(project));
    });

    const sortedWeeks = Object.keys(weeklyStats).sort();
    const datasets = Array.from(allProjects).map((project) => ({
      label: project,
      data: sortedWeeks.map((week) => weeklyStats[week][project] || 0),
      stack: "stack0",
    }));

    datasets.sort((a, b) => {
      const sumA = a.data.reduce((acc, val) => acc + val, 0);
      const sumB = b.data.reduce((acc, val) => acc + val, 0);
      return sumB - sumA;
    });

    chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels: sortedWeeks.map((week) => {
          const date = new Date(week);
          return date.toLocaleDateString("en-US", {
            month: "short",
            day: "numeric",
          });
        }),
        datasets,
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            stacked: true,
            grid: { display: false },
          },
          y: {
            stacked: true,
            type: "linear",
            grid: {
              color: (ctx: any) => {
                if (ctx.tick.value === 0) return "transparent";
                return ctx.tick.value % 1 === 0
                  ? "rgba(0, 0, 0, 0.1)"
                  : "rgba(0, 0, 0, 0.05)";
              },
            },
            ticks: {
              callback(value: string | number) {
                const v = Number(value);
                if (v === 0) return "0s";
                const hours = Math.floor(v / 3600);
                const minutes = Math.floor((v % 3600) / 60);
                return hours > 0 ? `${hours}h` : `${minutes}m`;
              },
            },
          },
        },
        plugins: {
          legend: {
            position: "right" as const,
            labels: {
              boxWidth: 12,
              padding: 15,
            },
          },
          tooltip: {
            callbacks: {
              label(context: any) {
                const value = context.raw as number;
                const hours = Math.floor(value / 3600);
                const minutes = Math.floor((value % 3600) / 60);
                const duration =
                  hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
                return `${context.dataset.label}: ${duration}`;
              },
            },
          },
        },
      },
    });
  }

  onMount(() => {
    if (Object.keys(weeklyStats).length > 0) createChart();
  });

  onDestroy(() => {
    if (chart) chart.destroy();
  });
</script>

<div class="bg-dark border border-primary rounded-xl p-6 flex flex-col">
  <h2 class="mb-4 text-xl font-semibold text-white">Project Timeline</h2>
  <div class="flex-1 relative min-h-48">
    <canvas bind:this={canvas} class="max-h-full w-full"></canvas>
  </div>
</div>
