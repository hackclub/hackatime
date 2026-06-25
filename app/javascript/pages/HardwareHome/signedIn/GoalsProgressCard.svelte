<script lang="ts">
  import { secondsToDisplay } from "./utils";

  type Goal = {
    id: string;
    period: "day" | "week" | "month";
    target_seconds: number;
    tracked_seconds: number;
    completion_percent: number;
    complete: boolean;
    languages: string[];
    projects: string[];
    period_end: string;
  };

  let { goals }: { goals: Goal[] } = $props();

  const RADIUS = 20;
  const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
  const clamp = (p: number) => Math.max(0, Math.min(p || 0, 100));
  const strokeDashoffset = (p: number) =>
    CIRCUMFERENCE - (clamp(p) / 100) * CIRCUMFERENCE;

  const PERIOD_LABELS = {
    day: "Daily goal",
    week: "Weekly goal",
    month: "Monthly goal",
  } as const;

  function scopeSubtitle(g: Goal) {
    const lang = g.languages.length
      ? `Languages: ${g.languages.join(", ")}`
      : "";
    const proj = g.projects.length ? `Projects: ${g.projects.join(", ")}` : "";
    if (lang && proj) return `${lang} AND ${proj}`;
    return lang || proj || "All programming activity";
  }

  function lastItemSpanClass(i: number, total: number): string {
    if (i !== total - 1) return "";
    const parts: string[] = [];
    if (total % 2 === 1) parts.push("sm:col-span-2");
    const r = total % 3;
    parts.push(
      r === 1 ? "xl:col-span-3" : r === 2 ? "xl:col-span-2" : "xl:col-span-1",
    );
    return parts.join(" ");
  }

  function periodTimeLeft(g: Goal) {
    if (g.complete) return "Done!";
    const diffMs = new Date(g.period_end).getTime() - Date.now();
    if (diffMs <= 0) return "Period ended";
    const diffHours = diffMs / 3_600_000;
    if (diffHours < 1) return `${Math.ceil(diffMs / 60_000)}m left today`;
    if (diffHours < 24) return `${Math.ceil(diffHours)}h left today`;
    const days = Math.ceil(diffMs / 86_400_000);
    return `${days} day${days === 1 ? "" : "s"} left`;
  }
</script>

{#if goals.length > 0}
  <section
    class="grid grid-cols-1 overflow-hidden rounded-xl border border-surface-200 bg-surface-100/30 sm:grid-cols-2 xl:grid-cols-3"
  >
    {#each goals as goal, i}
      {@const tone = goal.complete ? "text-success" : "text-muted"}
      <div
        class="flex min-w-0 flex-col gap-4 p-4 md:p-5 border-b border-surface-200 last:border-b-0 {lastItemSpanClass(
          i,
          goals.length,
        )}"
      >
        <div class="flex items-start justify-between gap-4">
          <div class="min-w-0">
            <p
              class="text-2xl font-bold tracking-tight {goal.complete
                ? 'text-success'
                : 'text-surface-content'}"
            >
              {secondsToDisplay(goal.tracked_seconds)}<span
                class="text-base font-normal text-muted"
              >
                / {secondsToDisplay(goal.target_seconds)}</span
              >
            </p>
            <p class="mt-0.5 truncate text-xs text-muted">
              {scopeSubtitle(goal)}
            </p>
          </div>

          <div class="flex items-center gap-2.5 shrink-0">
            <div class="text-right">
              <p class="text-sm font-medium {tone}">
                {PERIOD_LABELS[goal.period]}
              </p>
              <p class="text-xs mt-0.5 {tone}">{periodTimeLeft(goal)}</p>
            </div>

            <svg width="52" height="52" viewBox="0 0 52 52" class="shrink-0">
              <circle
                cx="26"
                cy="26"
                r={RADIUS}
                fill="none"
                stroke-width="3"
                class={goal.complete
                  ? "stroke-success/20"
                  : "stroke-surface-300"}
              />
              <circle
                cx="26"
                cy="26"
                r={RADIUS}
                fill="none"
                stroke-width="3"
                stroke-linecap="round"
                class={goal.complete ? "stroke-success" : "stroke-primary"}
                stroke-dasharray={CIRCUMFERENCE}
                stroke-dashoffset={strokeDashoffset(goal.completion_percent)}
                transform="rotate(-90 26 26)"
                style="transition: stroke-dashoffset 0.5s ease-out"
              />
              {#if goal.complete}
                <polyline
                  points="18,26 23,31 34,20"
                  fill="none"
                  stroke-width="2.5"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                  class="stroke-success"
                />
              {:else}
                <text
                  x="26"
                  y="26"
                  text-anchor="middle"
                  dominant-baseline="central"
                  class="fill-surface-content"
                  font-size="12"
                  font-weight="700">{Math.round(goal.completion_percent)}%</text
                >
              {/if}
            </svg>
          </div>
        </div>

        <div class="h-1.5 w-full overflow-hidden rounded-full bg-surface-200">
          <div
            class="h-full rounded-full transition-all duration-500 ease-out {goal.complete
              ? 'bg-success'
              : 'bg-primary'}"
            style="width: {clamp(goal.completion_percent)}%"
          ></div>
        </div>
      </div>
    {/each}
  </section>
{/if}
