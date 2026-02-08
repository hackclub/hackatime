<script lang="ts">
  import { onMount, onDestroy } from "svelte";

  let {
    title,
    stats,
  }: {
    title: string;
    stats: Record<string, number>;
  } = $props();

  let canvas: HTMLCanvasElement;
  let chart: any = null;

  const PIE_COLORS = [
    "#60a5fa", "#f472b6", "#fb923c", "#facc15", "#4ade80",
    "#2dd4bf", "#a78bfa", "#f87171", "#38bdf8", "#e879f9",
    "#34d399", "#fbbf24", "#818cf8", "#fb7185", "#22d3ee",
    "#a3e635", "#c084fc", "#f97316", "#14b8a6", "#8b5cf6",
    "#ec4899", "#84cc16", "#06b6d4", "#d946ef", "#10b981",
  ];

  function formatDuration(seconds: number): string {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
  }

  async function createChart() {
    if (chart) chart.destroy();

    const { Chart, PieController, ArcElement, Tooltip, Legend } = await import("chart.js");
    Chart.register(PieController, ArcElement, Tooltip, Legend);

    const labels = Object.keys(stats);
    const data = Object.values(stats);
    const total = data.reduce((a, b) => a + b, 0);
    const backgroundColors = labels.map((_, i) => PIE_COLORS[i % PIE_COLORS.length]);

    chart = new Chart(canvas, {
      type: "pie",
      data: {
        labels,
        datasets: [{ data, backgroundColor: backgroundColors, borderWidth: 1 }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.2,
        plugins: {
          tooltip: {
            callbacks: {
              label(context: any) {
                const label = context.label || "";
                const value = (context.raw as number) || 0;
                const duration = formatDuration(value);
                const percentage = ((value / total) * 100).toFixed(1);
                return `${label}: ${duration} (${percentage}%)`;
              },
            },
          },
          legend: {
            position: "right" as const,
            align: "center" as const,
            labels: {
              boxWidth: 10,
              padding: 8,
              font: { size: 10 },
            },
          },
        },
      },
    });
  }

  onMount(() => {
    if (Object.keys(stats).length > 0) createChart();
  });

  onDestroy(() => {
    if (chart) chart.destroy();
  });
</script>

<div class="bg-dark border border-primary rounded-xl p-6 flex flex-col">
  <h2 class="mb-4 text-xl font-semibold text-white">{title}</h2>
  <div class="flex-1 relative min-h-48">
    <canvas bind:this={canvas} class="max-h-full w-full"></canvas>
  </div>
</div>
