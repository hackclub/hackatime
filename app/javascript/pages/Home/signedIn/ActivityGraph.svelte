<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../../types/index";
  import { durationInWords } from "../../../utils";
  import { settingsProfile } from "../../../api";

  let { data }: { data: ActivityGraphData } = $props();

  const timezoneSettingsPath = `${settingsProfile.my.path()}#user_timezone`;
  const cellSize = 12;
  const cellGap = 4;
  const rows = 7;

  let canvas: HTMLCanvasElement;
  let hoveredDate = $state<string | null>(null);
  let focusedIndex = $state<number | null>(null);
  let canvasHasFocus = $state(false);

  const dates = $derived(buildDateRange(data.start_date, data.end_date));
  const columns = $derived(Math.ceil(dates.length / rows));
  const graphWidth = $derived(
    columns > 0 ? columns * cellSize + (columns - 1) * cellGap : 0,
  );
  const graphHeight = rows * cellSize + (rows - 1) * cellGap;
  const focusedDate = $derived(
    focusedIndex === null ? null : (dates[focusedIndex] ?? null),
  );
  const activeDate = $derived(hoveredDate ?? focusedDate);
  const hoveredSeconds = $derived(
    activeDate ? (data.duration_by_date[activeDate] ?? 0) : 0,
  );
  const hoveredTitle = $derived(
    activeDate
      ? `you hacked for ${durationInWords(hoveredSeconds)} on ${activeDate}`
      : "Daily coding activity graph",
  );

  function buildDateRange(startStr: string, endStr: string): string[] {
    const out: string[] = [];
    const cur = new Date(startStr + "T00:00:00");
    const end = new Date(endStr + "T00:00:00");
    while (cur <= end) {
      out.push(cur.toISOString().slice(0, 10));
      cur.setDate(cur.getDate() + 1);
    }
    return out;
  }

  function intensityLevel(seconds: number, busiest: number): number {
    if (seconds < 60) return 0;
    const r = seconds / busiest;
    if (r >= 0.8) return 4;
    if (r >= 0.5) return 3;
    if (r >= 0.2) return 2;
    return 1;
  }

  function activityColors(): string[] {
    const styles = getComputedStyle(canvas);
    const colors: string[] = [];

    for (let level = 0; level <= 4; level++) {
      colors[level] = styles
        .getPropertyValue(`--activity-cell-${level}`)
        .trim();
    }

    return colors;
  }

  function drawGraph() {
    if (!canvas) return;

    const context = canvas.getContext("2d");
    if (!context) return;

    const scale = window.devicePixelRatio || 1;
    canvas.width = graphWidth * scale;
    canvas.height = graphHeight * scale;
    canvas.style.width = `${graphWidth}px`;
    canvas.style.height = `${graphHeight}px`;

    context.setTransform(scale, 0, 0, scale, 0, 0);
    context.clearRect(0, 0, graphWidth, graphHeight);

    const colors = activityColors();
    const focusColor = getComputedStyle(canvas)
      .getPropertyValue("--color-surface-content")
      .trim();
    for (const [index, date] of dates.entries()) {
      const seconds = data.duration_by_date[date] ?? 0;
      const column = Math.floor(index / rows);
      const row = index % rows;
      const x = column * (cellSize + cellGap);
      const y = row * (cellSize + cellGap);
      context.fillStyle =
        colors[intensityLevel(seconds, data.busiest_day_seconds)];
      context.beginPath();
      context.roundRect(x, y, cellSize, cellSize, 2);
      context.fill();

      if (canvasHasFocus && index === focusedIndex) {
        context.strokeStyle = focusColor;
        context.lineWidth = 2;
        context.stroke();
      }
    }
  }

  function clampIndex(index: number): number {
    return Math.max(0, Math.min(index, dates.length - 1));
  }

  function onFocus() {
    canvasHasFocus = true;
    focusedIndex ??= 0;
  }

  function onBlur() {
    canvasHasFocus = false;
  }

  function dateFromPointer(event: MouseEvent): string | null {
    const rect = canvas.getBoundingClientRect();
    const x = event.clientX - rect.left;
    const y = event.clientY - rect.top;
    const column = Math.floor(x / (cellSize + cellGap));
    const row = Math.floor(y / (cellSize + cellGap));
    const inCellX = x % (cellSize + cellGap) < cellSize;
    const inCellY = y % (cellSize + cellGap) < cellSize;
    const index = column * rows + row;

    return inCellX && inCellY && row < rows && index < dates.length
      ? dates[index]
      : null;
  }

  function onPointerMove(event: PointerEvent) {
    hoveredDate = dateFromPointer(event);
  }

  function onClick(event: MouseEvent) {
    const date = dateFromPointer(event);
    if (date) router.visit(`?date=${date}`);
  }

  function onKeydown(event: KeyboardEvent) {
    if (!dates.length) return;

    focusedIndex ??= 0;

    if (event.key === "ArrowRight") {
      event.preventDefault();
      focusedIndex = clampIndex(focusedIndex + rows);
    } else if (event.key === "ArrowLeft") {
      event.preventDefault();
      focusedIndex = clampIndex(focusedIndex - rows);
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      focusedIndex = clampIndex(focusedIndex + 1);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      focusedIndex = clampIndex(focusedIndex - 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      focusedIndex = 0;
    } else if (event.key === "End") {
      event.preventDefault();
      focusedIndex = dates.length - 1;
    } else if ((event.key === "Enter" || event.key === " ") && focusedDate) {
      event.preventDefault();
      router.visit(`?date=${focusedDate}`);
    }
  }

  $effect(drawGraph);
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <canvas
    bind:this={canvas}
    class="block cursor-pointer"
    aria-label={hoveredTitle}
    title={hoveredTitle}
    role="button"
    tabindex="0"
    onfocus={onFocus}
    onblur={onBlur}
    onpointermove={onPointerMove}
    onpointerleave={() => (hoveredDate = null)}
    onclick={onClick}
    onkeydown={onKeydown}
  ></canvas>
  <p class="super">
    Calculated in
    <Link href={timezoneSettingsPath}>{data.timezone_label}</Link>
  </p>
</div>
