<script lang="ts">
  import { RadioGroup } from "bits-ui";
  import { page } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import eventsConfig from "../../../../../config/events.json";

  type EventConfig = {
    human_name: string;
    starts_at: string;
    ends_at: string;
    timezone: string;
    all_day?: boolean;
  };

  const EVENT_RANGES = eventsConfig as Record<string, EventConfig>;

  const STANDARD_INTERVALS = [
    { key: "today", label: "Today" },
    { key: "yesterday", label: "Yesterday" },
    { key: "this_week", label: "This Week" },
    { key: "last_7_days", label: "Last 7 Days" },
    { key: "this_month", label: "This Month" },
    { key: "last_30_days", label: "Last 30 Days" },
    { key: "this_year", label: "This Year" },
    { key: "last_12_months", label: "Last 12 Months" },
  ] as const;
  const EVENT_INTERVALS = Object.entries(EVENT_RANGES).map(([key, cfg]) => ({
    key,
    label: cfg.human_name,
  }));
  const INTERVALS = [
    ...STANDARD_INTERVALS,
    ...EVENT_INTERVALS,
    { key: "", label: "All Time" },
  ] as const;

  const DATE_INPUT_CLS =
    "ml-2 h-9 rounded-md border border-surface-content/20 bg-dark px-3 text-sm text-muted transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark";

  let {
    selected,
    from,
    to,
    onapply,
  }: {
    selected: string;
    from: string;
    to: string;
    onapply: (interval: string, from: string, to: string) => void;
  } = $props();

  let customFrom = $state(from);
  let customTo = $state(to);

  const currentUser = page.props.layout.nav.current_user!;
  const userCreatedAt = currentUser.created_at
    ? Date.parse(currentUser.created_at)
    : 0;
  // null = user hasn't been backfilled yet, so we can't trust the bitmap
  const participated = currentUser.event_participation
    ? new Set(currentUser.event_participation)
    : null;

  $effect(() => {
    customFrom = from;
    customTo = to;
  });

  const selectedIntervalValue = $derived(
    selected && !from && !to ? selected : "",
  );

  const visibleIntervals = $derived(
    INTERVALS.filter((interval) => {
      const range = EVENT_RANGES[interval.key];
      if (!range) return true;
      if (interval.key === selected) return true;

      const endsAt = eventEndsAt(range);
      // Ended event + backfilled: show only if the user actually participated.
      // Otherwise (active/future event, or not-yet-backfilled user) fall back
      // to the cheap "did the user exist before the event ended" check.
      if (endsAt < Date.now() && participated) {
        return participated.has(interval.key);
      }
      return userCreatedAt <= endsAt;
    }),
  );

  function selectInterval(key: string) {
    onapply(key, "", "");
  }

  function applyCustomRange() {
    onapply("", customFrom, customTo);
  }

  function eventEndsAt(range: EventConfig): number {
    const time =
      range.all_day === false ? range.ends_at : `${range.ends_at} 23:59:59`;
    return zonedTimeToUtcMs(time, range.timezone);
  }

  function zonedTimeToUtcMs(value: string, timeZone: string): number {
    const [datePart, timePart = "00:00:00"] = value.split(" ");
    const [year, month, day] = datePart.split("-").map(Number);
    const [hour, minute, second] = timePart.split(":").map(Number);
    const localAsUtc = Date.UTC(year, month - 1, day, hour, minute, second);
    return localAsUtc - timezoneOffsetMs(timeZone, localAsUtc);
  }

  function timezoneOffsetMs(timeZone: string, timestamp: number): number {
    const parts = new Intl.DateTimeFormat("en-US", {
      timeZone,
      hour12: false,
      hourCycle: "h23",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).formatToParts(new Date(timestamp));
    const values = Object.fromEntries(
      parts.map((part) => [part.type, part.value]),
    );
    const zonedAsUtc = Date.UTC(
      Number(values.year),
      Number(values.month) - 1,
      Number(values.day),
      Number(values.hour),
      Number(values.minute),
      Number(values.second),
    );
    return zonedAsUtc - timestamp;
  }
</script>

<div class="m-0 max-h-56 overflow-y-auto">
  <RadioGroup.Root
    value={selectedIntervalValue}
    onValueChange={selectInterval}
    class="flex flex-col gap-1 overflow-hidden"
  >
    {#each visibleIntervals as interval (interval.key)}
      <RadioGroup.Item
        value={interval.key}
        class="flex w-full items-center rounded-md px-3 py-2 text-left text-sm text-muted outline-none transition-all duration-150 hover:bg-surface-100/60 hover:text-surface-content data-[highlighted]:bg-surface-100/70 data-[state=checked]:bg-primary/12 data-[state=checked]:text-surface-content"
      >
        {#snippet children({ checked })}
          <span
            class="mr-3 h-4 w-4 min-w-4 rounded-full border transition-colors {checked
              ? 'border-primary bg-primary shadow-[0_0_0_3px_rgba(0,0,0,0.2)]'
              : 'border-surface-content/35 bg-surface/40'}"
          ></span>
          <span>{interval.label}</span>
        {/snippet}
      </RadioGroup.Item>
    {/each}
  </RadioGroup.Root>
</div>

<div class="mt-2 border-t border-surface-content/15 pt-2">
  <div class="flex flex-col gap-2">
    <label class="flex items-center justify-between text-sm text-muted">
      <span class="text-secondary/80">Start</span>
      <input type="date" class={DATE_INPUT_CLS} bind:value={customFrom} />
    </label>
    <label class="flex items-center justify-between text-sm text-muted">
      <span class="text-secondary/80">End</span>
      <input type="date" class={DATE_INPUT_CLS} bind:value={customTo} />
    </label>
  </div>
  <Button
    type="button"
    size="sm"
    class="mt-2 h-9 border-0"
    onclick={applyCustomRange}
  >
    Apply
  </Button>
</div>
