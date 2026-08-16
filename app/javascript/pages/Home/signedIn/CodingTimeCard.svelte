<script lang="ts">
  import type { ActivityGraphData } from "../../../types/index";
  import { secondsToDisplay } from "./utils";

  type PeriodAverage = {
    average_seconds: number;
    total_seconds: number;
    day_count: number;
    period_label: string;
  };

  let {
    activityGraph,
    periodAverage,
  }: {
    activityGraph: ActivityGraphData;
    periodAverage?: PeriodAverage | null;
  } = $props();

  function shiftDate(date: string, days: number) {
    const value = new Date(`${date}T00:00:00Z`);
    value.setUTCDate(value.getUTCDate() + days);
    return value.toISOString().slice(0, 10);
  }

  const todaySeconds = $derived(
    activityGraph.duration_by_date[activityGraph.end_date] ?? 0,
  );
  const comparisonDates = $derived(
    Array.from({ length: 8 }, (_, index) =>
      shiftDate(activityGraph.end_date, -(index + 1) * 7),
    ),
  );
  const averageSeconds = $derived(
    comparisonDates.reduce(
      (total, date) => total + (activityGraph.duration_by_date[date] || 0),
      0,
    ) / comparisonDates.length,
  );
  const percent = $derived(
    averageSeconds > 0 ? Math.round((todaySeconds / averageSeconds) * 100) : 0,
  );
  const changePercent = $derived(percent - 100);
  const gaugePercent = $derived(Math.min(percent, 100));
  const changeLabel = $derived(
    averageSeconds === 0
      ? todaySeconds > 0
        ? "First comparable session"
        : "No coding yet today"
      : changePercent === 0
        ? "Equal to your usual daily total"
        : changePercent > 0
          ? `+${changePercent}% vs usual daily total`
          : `${Math.abs(changePercent)}% below usual daily total`,
  );
</script>

<section
  class="flex min-h-64 flex-col rounded-2xl border border-surface-200 bg-dark p-4 sm:p-6"
>
  <div>
    <h3 class="text-lg font-semibold text-surface-content">
      {periodAverage ? "Average Coding Time Per Day" : "Coding Time Today"}
    </h3>
    <p class="text-sm text-surface-content/55">
      {periodAverage
        ? `Across ${periodAverage.period_label}`
        : "Compared with your last eight matching weekdays"}
    </p>
  </div>

  {#if periodAverage}
    <div class="my-auto flex flex-col items-center py-8 text-center">
      <p class="text-4xl font-semibold tabular-nums text-primary">
        {secondsToDisplay(periodAverage.average_seconds)}
      </p>
      <p class="mt-2 text-sm text-surface-content/55">
        per day across {periodAverage.day_count}
        {periodAverage.day_count === 1 ? "day" : "days"}
      </p>
      <p class="mt-4 text-sm text-surface-content/50">
        <span class="font-medium text-surface-content/75">
          {secondsToDisplay(periodAverage.total_seconds)}
        </span>
        total
      </p>
    </div>
  {:else}
    <div class="mt-auto flex flex-col items-center pt-4">
      <svg
        viewBox="0 0 180 105"
        class="h-32 w-full max-w-64"
        role="figure"
        aria-label={`${percent}% of your usual coding time today`}
      >
        <path
          d="M 20 90 A 70 70 0 0 1 160 90"
          pathLength="100"
          fill="none"
          class="stroke-surface-200/50"
          stroke-width="18"
          stroke-linecap="round"
        />
        <path
          d="M 20 90 A 70 70 0 0 1 160 90"
          pathLength="100"
          fill="none"
          class="stroke-primary transition-[stroke-dashoffset] duration-300 ease-out"
          stroke-width="18"
          stroke-linecap="round"
          stroke-dasharray="100"
          stroke-dashoffset={100 - gaugePercent}
        />
        <text
          x="90"
          y="88"
          text-anchor="middle"
          class="fill-surface-content text-xl font-semibold tabular-nums"
          >{percent}%</text
        >
      </svg>

      <p
        class:!text-green={changePercent > 0 && averageSeconds > 0}
        class:!text-red={changePercent < 0 && averageSeconds > 0}
        class="-mt-2 text-sm font-semibold text-surface-content/60"
      >
        {changeLabel}
      </p>
      <p class="mt-3 text-sm text-surface-content/50">
        Today <span class="font-medium text-surface-content/75"
          >{secondsToDisplay(todaySeconds)}</span
        >
        · Usual
        <span class="font-medium text-surface-content/75"
          >{secondsToDisplay(averageSeconds)}</span
        >
      </p>
    </div>
  {/if}
</section>
