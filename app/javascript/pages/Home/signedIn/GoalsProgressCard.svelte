<script lang="ts">
  import { secondsToDisplay } from "./utils";

  let {
    goals,
  }: {
    goals: {
      id: string;
      period: "day" | "week" | "month";
      target_seconds: number;
      tracked_seconds: number;
      completion_percent: number;
      complete: boolean;
      languages: string[];
      projects: string[];
      period_end: string;
    }[];
  } = $props();

  const percentWidth = (percent: number) =>
    `${Math.max(0, Math.min(percent || 0, 100))}%`;

  const periodLabel = (period: "day" | "week" | "month") => {
    if (period === "day") return "Daily goal";
    if (period === "week") return "Weekly goal";
    return "Monthly goal";
  };

  const scopeSubtitle = (goal: { languages: string[]; projects: string[] }) => {
    const languageScope =
      goal.languages.length > 0
        ? `Languages: ${goal.languages.join(", ")}`
        : "";
    const projectScope =
      goal.projects.length > 0 ? `Projects: ${goal.projects.join(", ")}` : "";

    if (languageScope && projectScope) {
      return `${languageScope} AND ${projectScope}`;
    }

    return languageScope || projectScope || "All programming activity";
  };

  function lastItemSpanClass(index: number, total: number): string {
    if (index !== total - 1) return "";
    const parts: string[] = [];

    // 2-column grid (sm): last item fills the row if total is odd
    if (total % 2 === 1) parts.push("sm:col-span-2");

    // 3-column grid (lg): last item fills remaining columns
    const lgRemainder = total % 3;
    if (lgRemainder === 1) parts.push("lg:col-span-3");
    else if (lgRemainder === 2) parts.push("lg:col-span-2");
    else parts.push("lg:col-span-1"); // reset sm:col-span-2

    return parts.join(" ");
  }

  // Arc progress ring
  const RADIUS = 20;
  const CIRCUMFERENCE = 2 * Math.PI * RADIUS;
  const strokeDashoffset = (percent: number) => {
    const clamped = Math.max(0, Math.min(percent || 0, 100));
    return CIRCUMFERENCE - (clamped / 100) * CIRCUMFERENCE;
  };

  const periodTimeLeft = (goal: { period_end: string; complete: boolean }) => {
    if (goal.complete) return "Done!";
    const now = new Date();
    const end = new Date(goal.period_end);
    const diffMs = end.getTime() - now.getTime();
    if (diffMs <= 0) return "Period ended";

    const diffHours = diffMs / (1000 * 60 * 60);
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

    if (diffHours < 1) {
      const mins = Math.ceil(diffMs / (1000 * 60));
      return `${mins}m left today`;
    }
    if (diffHours < 24) {
      return `${Math.ceil(diffHours)}h left today`;
    }
    return `${diffDays} day${diffDays === 1 ? "" : "s"} left`;
  };
</script>

{#if goals.length > 0}
  <section
    class="rounded-xl border border-surface-200 bg-surface-100/30 overflow-hidden grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
  >
    {#each goals as goal, i}
      <div
        class="p-4 md:p-5 flex flex-col gap-4
          border-b border-surface-200
          last:border-b-0
          {lastItemSpanClass(i, goals.length)}"
      >
        <div class="flex items-start justify-between gap-4">
          <!-- Left: Big time display -->
          <div>
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
            <p class="text-xs text-muted mt-0.5">{scopeSubtitle(goal)}</p>
          </div>

          <!-- Right: label + circular progress indicator -->
          <div class="flex items-center gap-2.5 shrink-0">
            <div class="text-right">
              <p
                class="text-sm font-medium {goal.complete
                  ? 'text-success'
                  : 'text-muted'}"
              >
                {periodLabel(goal.period)}
              </p>
              <p
                class="text-xs mt-0.5 {goal.complete
                  ? 'text-success'
                  : 'text-muted'}"
              >
                {periodTimeLeft(goal)}
              </p>
            </div>

            <!-- Circular progress indicator with percentage inside -->
            <svg
              width="52"
              height="52"
              viewBox="0 0 52 52"
              class="shrink-0"
            >
              <!-- Background track -->
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
              <!-- Progress arc -->
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

              <!-- Percentage text or checkmark -->
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
                  font-weight="700"
                >{Math.round(goal.completion_percent)}%</text>
              {/if}
            </svg>
          </div>
        </div>

        <!-- Progress bar -->
        <div class="h-1.5 w-full overflow-hidden rounded-full bg-surface-200">
          <div
            class="h-full rounded-full transition-all duration-500 ease-out {goal.complete
              ? 'bg-success'
              : 'bg-primary'}"
            style="width: {percentWidth(goal.completion_percent)}"
          ></div>
        </div>
      </div>
    {/each}
  </section>
{/if}


