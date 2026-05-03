<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import type { ActivityGraphData } from "../../../types/index";
  import { durationInWords } from "../../../utils";
  import { settingsProfile } from "../../../api";

  let { data }: { data: ActivityGraphData } = $props();

  // Deep-link to the timezone field on the profile settings page.
  const timezoneSettingsPath = `${settingsProfile.my.path()}#user_timezone`;

  function buildDateRange(startStr: string, endStr: string): string[] {
    const dates: string[] = [];
    const current = new Date(startStr + "T00:00:00");
    const end = new Date(endStr + "T00:00:00");
    while (current <= end) {
      dates.push(current.toISOString().slice(0, 10));
      current.setDate(current.getDate() + 1);
    }
    return dates;
  }

  function intensityClass(seconds: number, busiestDaySeconds: number): string {
    if (seconds < 60) return "activity-cell--0";
    const ratio = seconds / busiestDaySeconds;
    if (ratio >= 0.8) return "activity-cell--4";
    if (ratio >= 0.5) return "activity-cell--3";
    if (ratio >= 0.2) return "activity-cell--2";
    return "activity-cell--1";
  }

  const dates = $derived(buildDateRange(data.start_date, data.end_date));
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <div class="grid grid-rows-7 grid-flow-col gap-1 w-full lg:w-1/2">
    {#each dates as date}
      {@const seconds = data.duration_by_date[date] ?? 0}
      <Link
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
      </Link>
    {/each}
  </div>
  <p class="super">
    Calculated in
    <Link href={timezoneSettingsPath}>{data.timezone_label}</Link>
  </p>
</div>
