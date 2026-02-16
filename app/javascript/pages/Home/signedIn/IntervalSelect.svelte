<script lang="ts">
  import { Popover, RadioGroup } from "bits-ui";
  import Button from "../../../components/Button.svelte";

  const INTERVALS = [
    { key: "today", label: "Today" },
    { key: "yesterday", label: "Yesterday" },
    { key: "this_week", label: "This Week" },
    { key: "last_7_days", label: "Last 7 Days" },
    { key: "this_month", label: "This Month" },
    { key: "last_30_days", label: "Last 30 Days" },
    { key: "this_year", label: "This Year" },
    { key: "last_12_months", label: "Last 12 Months" },
    { key: "flavortown", label: "Flavortown" },
    { key: "summer_of_making", label: "Summer of Making" },
    { key: "high_seas", label: "High Seas" },
    { key: "low_skies", label: "Low Skies" },
    { key: "scrapyard", label: "Scrapyard Global" },
    { key: "", label: "All Time" },
  ] as const;

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

  let open = $state(false);
  let customFrom = $state("");
  let customTo = $state("");

  $effect(() => {
    customFrom = from;
    customTo = to;
  });

  const displayLabel = $derived.by(() => {
    if (selected && selected !== "custom") {
      return INTERVALS.find((i) => i.key === selected)?.label ?? selected;
    }
    if (from && to) return `${from} to ${to}`;
    if (from) return `From ${from}`;
    if (to) return `Until ${to}`;
    return "All Time";
  });

  const isDefault = $derived(!selected && !from && !to);
  const selectedIntervalValue = $derived(selected && !from && !to ? selected : "");

  function selectInterval(key: string) {
    onchange(key, "", "");
    open = false;
  }

  function applyCustomRange() {
    onchange("", customFrom, customTo);
    open = false;
  }

  function clear() {
    onchange("", "", "");
    open = false;
  }
</script>

<div class="filter relative">
  <span class="block text-xs font-medium mb-1.5 text-secondary/80 uppercase tracking-wider">
    Date Range
  </span>

  <Popover.Root bind:open>
    <div class="group m-0 flex items-center rounded-lg border border-surface-200 bg-surface-100 p-0 transition-all duration-200 hover:border-surface-300 hover:bg-surface-200 focus-within:border-primary/70 focus-within:ring-2 focus-within:ring-primary/35 focus-within:ring-offset-1 focus-within:ring-offset-surface">
      <Popover.Trigger>
        {#snippet child({ props })}
          <Button
            type="button"
            unstyled
            class="m-0 flex flex-1 cursor-pointer select-none items-center justify-between border-0 bg-transparent px-3 py-2.5 text-sm text-surface-content"
            {...props}
          >
            <span class="font-medium">{displayLabel}</span>
            <svg class={`h-4 w-4 text-secondary/60 transition-all duration-200 group-hover:text-secondary ${open ? "rotate-180 text-primary" : ""}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
            </svg>
          </Button>
        {/snippet}
      </Popover.Trigger>

      {#if !isDefault}
        <Button
          type="button"
          unstyled
          class="m-0 cursor-pointer border-0 border-l border-surface-200 bg-transparent px-2.5 py-2 text-sm leading-none text-secondary/60 transition-colors duration-150 hover:bg-red/10 hover:text-red"
          onclick={clear}
        >
          ✕
        </Button>
      {/if}
    </div>

    <Popover.Portal>
      <Popover.Content
        sideOffset={8}
        align="start"
        class="dashboard-select-popover z-1000 w-[min(22rem,calc(100vw-2rem))] rounded-xl border border-surface-content/20 bg-darkless/95 p-4 shadow-xl shadow-black/50 outline-none backdrop-blur-sm"
      >
        <div class="m-0 max-h-56 overflow-y-auto">
          <RadioGroup.Root
            value={selectedIntervalValue}
            onValueChange={selectInterval}
            class="flex flex-col gap-1 overflow-hidden"
          >
            {#each INTERVALS as interval}
              <RadioGroup.Item
                value={interval.key}
                class="flex w-full items-center rounded-md px-3 py-2 text-left text-sm text-muted outline-none transition-all duration-150 hover:bg-surface-100/60 hover:text-surface-content data-[highlighted]:bg-surface-100/70 data-[state=checked]:bg-primary/12 data-[state=checked]:text-surface-content"
              >
                {#snippet children({ checked })}
                  <span class={`mr-3 h-4 w-4 min-w-4 rounded-full border transition-colors ${checked ? "border-primary bg-primary shadow-[0_0_0_3px_rgba(0,0,0,0.2)]" : "border-surface-content/35 bg-surface/40"}`}></span>
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
              <input
                type="date"
                class="ml-2 h-9 rounded-md border border-surface-content/20 bg-dark px-3 text-sm text-muted transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark"
                bind:value={customFrom}
              />
            </label>
            <label class="flex items-center justify-between text-sm text-muted">
              <span class="text-secondary/80">End</span>
              <input
                type="date"
                class="ml-2 h-9 rounded-md border border-surface-content/20 bg-dark px-3 text-sm text-muted transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark"
                bind:value={customTo}
              />
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
      </Popover.Content>
    </Popover.Portal>
  </Popover.Root>
</div>
