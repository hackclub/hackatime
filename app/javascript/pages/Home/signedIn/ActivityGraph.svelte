<script lang="ts">
  import { Link, router } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../../types/index";
  import { durationInWords } from "../../../utils";
  import { settingsProfile } from "../../../api";

  let { data }: { data: ActivityGraphData } = $props();

  const timezoneSettingsPath = `${settingsProfile.my.path()}#user_timezone`;

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

  function intensityClass(seconds: number, busiest: number): string {
    if (seconds < 60) return "activity-cell--0";
    const r = seconds / busiest;
    if (r >= 0.8) return "activity-cell--4";
    if (r >= 0.5) return "activity-cell--3";
    if (r >= 0.2) return "activity-cell--2";
    return "activity-cell--1";
  }

  const dates = $derived(buildDateRange(data.start_date, data.end_date));

  function onCellClick(e: MouseEvent) {
    const target = (e.target as HTMLElement | null)?.closest<HTMLAnchorElement>(
      "a.activity-cell",
    );
    if (!target) return;
    // Let modified clicks (cmd/ctrl/shift/middle-click) fall through to native handling.
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey || e.button !== 0)
      return;
    e.preventDefault();
    router.visit(target.getAttribute("href") || "");
  }
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <!-- svelte-ignore a11y_no_static_element_interactions -->
  <div
    class="grid grid-rows-7 grid-flow-col gap-1 w-full lg:w-1/2"
    onclick={onCellClick}
  >
    {#each dates as date}
      {@const seconds = data.duration_by_date[date] ?? 0}
      <a
        class="day activity-cell transition-all duration-75 w-3 h-3 rounded-sm hover:scale-110 hover:z-10 hover:shadow-md {intensityClass(
          seconds,
          data.busiest_day_seconds,
        )}"
        href="?date={date}"
        title="you hacked for {durationInWords(seconds)} on {date}"
        data-date={date}
        data-duration={durationInWords(seconds)}
      >
        &nbsp;
      </a>
    {/each}
  </div>
  <p class="super">
    Calculated in
    <Link href={timezoneSettingsPath}>{data.timezone_label}</Link>
  </p>
</div>
