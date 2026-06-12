<script lang="ts">
  import { onMount } from "svelte";
  import type { Component } from "svelte";
  import FilterShell from "./FilterShell.svelte";
  import eventsConfig from "../../../../../config/events.json";

  const STANDARD_INTERVAL_LABELS: Record<string, string> = {
    today: "Today",
    yesterday: "Yesterday",
    this_week: "This Week",
    last_7_days: "Last 7 Days",
    this_month: "This Month",
    last_30_days: "Last 30 Days",
    this_year: "This Year",
    last_12_months: "Last 12 Months",
  };

  type EventConfig = {
    human_name: string;
  };

  const EVENT_INTERVAL_LABELS = Object.fromEntries(
    Object.entries(eventsConfig as Record<string, EventConfig>).map(
      ([key, cfg]) => [key, cfg.human_name],
    ),
  );

  const INTERVAL_LABELS: Record<string, string> = {
    ...STANDARD_INTERVAL_LABELS,
    ...EVENT_INTERVAL_LABELS,
  };

  let {
    selected,
    from,
    to,
    onchange,
  }: {
    selected: string;
    from: string;
    to: string;
    onchange: (interval: string, from: string, to: string) => void;
  } = $props();

  type BodyProps = {
    selected: string;
    from: string;
    to: string;
    onapply: (interval: string, from: string, to: string) => void;
  };

  let open = $state(false);
  let Body = $state<Component<BodyProps> | null>(null);

  const displayLabel = $derived.by(() => {
    if (selected && selected !== "custom")
      return INTERVAL_LABELS[selected] ?? selected;
    if (from && to) return `${from} to ${to}`;
    if (from) return `From ${from}`;
    if (to) return `Until ${to}`;
    return "All Time";
  });

  const isDefault = $derived(!selected && !from && !to);

  function loadBody() {
    if (Body) return;
    import("./IntervalSelectBody.svelte").then((m) => {
      Body = m.default;
    });
  }

  onMount(() => {
    const w = window as unknown as {
      requestIdleCallback?: (
        cb: () => void,
        opts?: { timeout?: number },
      ) => void;
    };
    if (typeof w.requestIdleCallback === "function") {
      w.requestIdleCallback(loadBody, { timeout: 2000 });
    } else {
      setTimeout(loadBody, 300);
    }
  });

  $effect(() => {
    if (open) loadBody();
  });

  function handleApply(interval: string, f: string, t: string) {
    onchange(interval, f, t);
    open = false;
  }

  function clear() {
    onchange("", "", "");
    open = false;
  }
</script>

<FilterShell
  label="Date Range"
  displayText={displayLabel}
  canClear={!isDefault}
  onclear={clear}
  bind:open
>
  {#snippet content()}
    {#if Body}
      <Body {selected} {from} {to} onapply={handleApply} />
    {:else}
      <div
        class="flex items-center justify-center px-3 py-8 text-sm text-muted/70"
      >
        Loading…
      </div>
    {/if}
  {/snippet}
</FilterShell>
