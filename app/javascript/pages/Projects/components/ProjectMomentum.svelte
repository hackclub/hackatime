<script lang="ts">
  import type { ProjectMomentum } from "../types";
  import { secondsToDisplay } from "../../Home/signedIn/utils";

  let { momentum }: { momentum: ProjectMomentum } = $props();

  const WIDTH = 180;
  const HEIGHT = 44;
  const PADDING = 3;
  const values = $derived(momentum.weeks.map((week) => week.duration_seconds));
  const maximum = $derived(Math.max(...values, 1));
  const points = $derived(
    values.map((value, index) => ({
      x:
        PADDING +
        (index / Math.max(values.length - 1, 1)) * (WIDTH - PADDING * 2),
      y: HEIGHT - PADDING - (value / maximum) * (HEIGHT - PADDING * 2),
      value,
      week: momentum.weeks[index]?.week || "",
    })),
  );
  const line = $derived(
    points.map((point) => `${point.x},${point.y}`).join(" "),
  );
  const area = $derived(
    points.length > 0
      ? `M ${points[0].x} ${HEIGHT - PADDING} L ${points.map((point) => `${point.x} ${point.y}`).join(" L ")} L ${points.at(-1)?.x} ${HEIGHT - PADDING} Z`
      : "",
  );
  const trendLabel = $derived(
    momentum.trend === "new"
      ? "New"
      : momentum.trend === "steady"
        ? "Steady"
        : `${momentum.change_percent && momentum.change_percent > 0 ? "+" : ""}${momentum.change_percent}%`,
  );
  const trendClass = $derived(
    momentum.trend === "increasing"
      ? "text-green"
      : momentum.trend === "decreasing"
        ? "text-red"
        : "text-surface-content/55",
  );
</script>

<div class="relative z-20 mt-4 border-t border-surface-200/40 pt-3">
  <div class="mb-1.5 flex items-baseline justify-between gap-3 text-xs">
    <p class="text-surface-content/55">
      Last 4 weeks
      <span class="font-semibold text-surface-content/80"
        >{momentum.current_label}</span
      >
    </p>
    <p class={`font-semibold ${trendClass}`}>{trendLabel}</p>
  </div>

  <svg
    viewBox={`0 0 ${WIDTH} ${HEIGHT}`}
    class="h-11 w-full overflow-visible"
    role="figure"
    aria-label={`Eight week coding momentum: ${trendLabel}`}
  >
    {#if points.length > 0}
      <path d={area} class="fill-primary/10" />
      <polyline
        points={line}
        fill="none"
        class="stroke-primary"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
      {#each points as point (point.week)}
        <circle
          cx={point.x}
          cy={point.y}
          r="2.5"
          class="fill-dark stroke-primary"
          stroke-width="1.5"
          aria-label={`Week of ${point.week}: ${secondsToDisplay(point.value)}`}
        >
          <title>Week of {point.week}: {secondsToDisplay(point.value)}</title>
        </circle>
      {/each}
    {/if}
  </svg>

  {#if momentum.last_active_label}
    <p class="mt-1 text-xs text-surface-content/45">
      Last active
      <time datetime={momentum.last_active_at || undefined}
        >{momentum.last_active_label}</time
      >
    </p>
  {/if}
</div>
