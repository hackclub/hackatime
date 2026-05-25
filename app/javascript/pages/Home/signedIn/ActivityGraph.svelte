<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../../types/index";
  import { durationInWords } from "../../../utils";
  import { settingsProfile } from "../../../api";

  let { data }: { data: ActivityGraphData } = $props();

  const timezoneSettingsPath = `${settingsProfile.my.path()}#user_timezone`;

  const CELL = 12;
  const GAP = 4;
  const STEP = CELL + GAP;
  const RADIUS = 2;

  type CellMeta = { date: string; seconds: number };

  type GraphLayout = {
    paths: string[]; // one path per intensity bucket (0-4)
    metaByCol: CellMeta[][]; // metaByCol[col][row] -> {date, seconds}
    cols: number;
    width: number;
    height: number;
  };

  function intensityBucket(seconds: number, busiest: number): number {
    if (seconds < 60) return 0;
    const r = seconds / busiest;
    if (r >= 0.8) return 4;
    if (r >= 0.5) return 3;
    if (r >= 0.2) return 2;
    return 1;
  }

  // Round-rect path component (using svg arc commands).
  function appendRoundRect(parts: string[], x: number, y: number) {
    const r = RADIUS;
    const w = CELL;
    const h = CELL;
    parts.push(
      `M${x + r},${y}`,
      `h${w - 2 * r}`,
      `a${r},${r} 0 0 1 ${r},${r}`,
      `v${h - 2 * r}`,
      `a${r},${r} 0 0 1 -${r},${r}`,
      `h-${w - 2 * r}`,
      `a${r},${r} 0 0 1 -${r},-${r}`,
      `v-${h - 2 * r}`,
      `a${r},${r} 0 0 1 ${r},-${r}`,
      `z`,
    );
  }

  function buildLayout(d: ActivityGraphData): GraphLayout {
    const cur = new Date(d.start_date + "T00:00:00");
    const end = new Date(d.end_date + "T00:00:00");
    const busiest = d.busiest_day_seconds || 1;
    const buckets: string[][] = [[], [], [], [], []];
    const metaByCol: CellMeta[][] = [];
    let col = 0;
    let curCol: CellMeta[] = [];
    metaByCol.push(curCol);

    while (cur <= end) {
      const dow = cur.getDay();
      const dateStr = cur.toISOString().slice(0, 10);
      const seconds = d.duration_by_date[dateStr] ?? 0;
      const bucket = intensityBucket(seconds, busiest);
      const x = col * STEP;
      const y = dow * STEP;
      appendRoundRect(buckets[bucket], x, y);
      curCol[dow] = { date: dateStr, seconds };

      cur.setDate(cur.getDate() + 1);
      if (cur.getDay() === 0) {
        col += 1;
        curCol = [];
        metaByCol.push(curCol);
      }
    }
    const cols = metaByCol[metaByCol.length - 1].length
      ? metaByCol.length
      : metaByCol.length - 1;
    return {
      paths: buckets.map((parts) => parts.join("")),
      metaByCol,
      cols,
      width: cols * STEP - GAP,
      height: 7 * STEP - GAP,
    };
  }

  const layout = $derived(buildLayout(data));

  let hovered = $state<{ x: number; y: number; meta: CellMeta } | null>(null);
  let svgEl: SVGSVGElement | undefined;

  function cellFromEvent(
    e: MouseEvent,
  ): { col: number; row: number; meta: CellMeta } | null {
    if (!svgEl) return null;
    const rect = svgEl.getBoundingClientRect();
    if (!rect.width || !rect.height) return null;
    const scaleX = layout.width / rect.width;
    const scaleY = layout.height / rect.height;
    const x = (e.clientX - rect.left) * scaleX;
    const y = (e.clientY - rect.top) * scaleY;
    const col = Math.floor(x / STEP);
    const row = Math.floor(y / STEP);
    if (col < 0 || col >= layout.cols || row < 0 || row > 6) return null;
    // Reject clicks in the gap between cells.
    if (x - col * STEP > CELL || y - row * STEP > CELL) return null;
    const meta = layout.metaByCol[col]?.[row];
    if (!meta) return null;
    return { col, row, meta };
  }

  function onClick(e: MouseEvent) {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0)
      return;
    const c = cellFromEvent(e);
    if (!c) return;
    e.preventDefault();
    router.visit(`?date=${c.meta.date}`);
  }

  function onMove(e: MouseEvent) {
    const c = cellFromEvent(e);
    if (!c) {
      if (hovered) hovered = null;
      return;
    }
    if (!hovered || hovered.meta.date !== c.meta.date) {
      hovered = {
        x: c.col * STEP + CELL / 2,
        y: c.row * STEP + CELL / 2,
        meta: c.meta,
      };
    }
  }
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <div class="relative w-full lg:w-1/2">
    <!-- svelte-ignore a11y_click_events_have_key_events -->
    <!-- svelte-ignore a11y_no_static_element_interactions -->
    <!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
    <svg
      bind:this={svgEl}
      class="activity-graph block w-full"
      viewBox={`0 0 ${layout.width} ${layout.height}`}
      preserveAspectRatio="xMinYMid meet"
      role="img"
      aria-label={`Activity heatmap${hovered ? `: ${durationInWords(hovered.meta.seconds)} on ${hovered.meta.date}` : ""}`}
      onclick={onClick}
      onmousemove={onMove}
      onmouseleave={() => (hovered = null)}
    >
      {#each layout.paths as d, bucket}
        {#if d}
          <path class={`activity-cell activity-cell--${bucket}`} {d} />
        {/if}
      {/each}
      {#if hovered}
        <rect
          class="activity-graph-hover"
          x={hovered.x - CELL / 2 - 1}
          y={hovered.y - CELL / 2 - 1}
          width={CELL + 2}
          height={CELL + 2}
          rx={RADIUS + 1}
          ry={RADIUS + 1}
        />
      {/if}
    </svg>
    {#if hovered}
      <div class="activity-graph-tooltip" role="status" aria-live="polite">
        you hacked for {durationInWords(hovered.meta.seconds)} on {hovered.meta
          .date}
      </div>
    {/if}
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
    cursor: pointer;
  }
  .activity-graph-hover {
    fill: none;
    stroke: var(--color-primary, currentColor);
    stroke-width: 1;
    pointer-events: none;
  }
  .activity-graph-tooltip {
    position: absolute;
    top: -1.5rem;
    left: 0;
    font-size: 0.75rem;
    color: var(--color-surface-content, currentColor);
    opacity: 0.85;
    pointer-events: none;
    white-space: nowrap;
  }
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
