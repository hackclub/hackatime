<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../../types/index";
  import { durationInWords } from "../../../utils";
  import { settingsProfile } from "../../../api";

  let { data }: { data: ActivityGraphData } = $props();

  const timezoneSettingsPath = `${settingsProfile.my.path()}#user_timezone`;

  const CELL = 12;
  const GAP = 4;

  type Cell = {
    date: string;
    x: number;
    y: number;
    seconds: number;
    cls: string;
  };

  function intensityClass(seconds: number, busiest: number): string {
    if (seconds < 60) return "activity-cell--0";
    const r = seconds / busiest;
    if (r >= 0.8) return "activity-cell--4";
    if (r >= 0.5) return "activity-cell--3";
    if (r >= 0.2) return "activity-cell--2";
    return "activity-cell--1";
  }

  function buildCells(d: ActivityGraphData): Cell[] {
    const out: Cell[] = [];
    const cur = new Date(d.start_date + "T00:00:00");
    const end = new Date(d.end_date + "T00:00:00");
    const busiest = d.busiest_day_seconds || 1;
    let col = 0;
    while (cur <= end) {
      const dateStr = cur.toISOString().slice(0, 10);
      const seconds = d.duration_by_date[dateStr] ?? 0;
      out.push({
        date: dateStr,
        x: col * (CELL + GAP),
        y: cur.getDay() * (CELL + GAP),
        seconds,
        cls: intensityClass(seconds, busiest),
      });
      cur.setDate(cur.getDate() + 1);
      if (cur.getDay() === 0) col += 1;
    }
    return out;
  }

  const cells = $derived(buildCells(data));
  const width = $derived(
    cells.length ? Math.max(...cells.map((c) => c.x)) + CELL : 0,
  );
  const height = 7 * (CELL + GAP) - GAP;

  function onCellClick(e: MouseEvent) {
    const t = e.target as SVGRectElement | null;
    if (!t || t.tagName.toLowerCase() !== "rect") return;
    const date = t.dataset.date;
    if (!date) return;
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0)
      return;
    e.preventDefault();
    router.visit(`?date=${date}`);
  }
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <div class="relative w-full lg:w-1/2">
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <svg
      class="activity-graph block w-full"
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="xMinYMid meet"
      role="img"
      aria-label="Daily activity heatmap"
      onclick={onCellClick}
    >
      {#each cells as cell}
        <rect
          x={cell.x}
          y={cell.y}
          width={CELL}
          height={CELL}
          rx="2"
          ry="2"
          class="activity-cell {cell.cls}"
          data-date={cell.date}
          ><title
            >you hacked for {durationInWords(cell.seconds)} on {cell.date}</title
          ></rect
        >
      {/each}
    </svg>
  </div>
  <p class="super">
    Calculated in
    <Link href={timezoneSettingsPath}>{data.timezone_label}</Link>
  </p>
</div>

<style>
  .activity-graph {
    max-width: 100%;
    height: auto;
  }
  .activity-graph rect {
    cursor: pointer;
    transition: fill 0.15s ease;
  }
  .activity-graph rect:hover {
    filter: brightness(1.15);
  }
  /* The existing .activity-cell--N selectors set background-color on <div>s;
     translate them to SVG fills via :global(). */
  :global(.activity-graph .activity-cell--0) {
    fill: color-mix(
      in oklab,
      var(--color-surface-content) 12%,
      var(--color-surface)
    );
  }
  :global(.activity-graph .activity-cell--1) {
    fill: color-mix(in oklab, var(--color-success) 35%, var(--color-surface));
  }
  :global(.activity-graph .activity-cell--2) {
    fill: color-mix(in oklab, var(--color-success) 50%, var(--color-surface));
  }
  :global(.activity-graph .activity-cell--3) {
    fill: color-mix(in oklab, var(--color-success) 68%, var(--color-surface));
  }
  :global(.activity-graph .activity-cell--4) {
    fill: color-mix(in oklab, var(--color-success) 85%, var(--color-surface));
  }
</style>
