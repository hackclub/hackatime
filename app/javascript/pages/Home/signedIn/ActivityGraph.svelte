<script lang="ts">
  import type { ActivityGraphData } from "../../../types/index";

  let { data }: { data: ActivityGraphData } = $props();

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

  function bgColor(seconds: number, busiestDaySeconds: number): string {
    if (seconds < 60) return "bg-[#151b23]";
    const ratio = seconds / busiestDaySeconds;
    if (ratio >= 0.8) return "bg-[#56d364]";
    if (ratio >= 0.5) return "bg-[#2ea043]";
    if (ratio >= 0.2) return "bg-[#196c2e]";
    return "bg-[#033a16]";
  }

  function durationInWords(seconds: number): string {
    if (seconds < 60) return "less than a minute";
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0) return `about ${hours} ${hours === 1 ? "hour" : "hours"}`;
    return `${minutes} ${minutes === 1 ? "minute" : "minutes"}`;
  }

  const dates = $derived(buildDateRange(data.start_date, data.end_date));
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5">
  <div class="grid grid-rows-7 grid-flow-col gap-1 w-full lg:w-1/2">
    {#each dates as date}
      {@const seconds = data.duration_by_date[date] ?? 0}
      <a
        class="day transition-all duration-75 w-3 h-3 rounded-sm hover:scale-110 hover:z-10 hover:shadow-md {bgColor(
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
    <a href={data.timezone_settings_path}>{data.timezone_label}</a>
  </p>
</div>
