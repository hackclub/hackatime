<script lang="ts">
  import { RadioGroup } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import FilterShell from "./FilterShell.svelte";

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

  const DATE_INPUT_CLS =
    "ml-2 h-9 rounded-md border border-surface-content/20 bg-dark px-3 text-sm text-muted transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark";

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
    if (selected && selected !== "custom")
      return INTERVALS.find((i) => i.key === selected)?.label ?? selected;
    if (from && to) return `${from} to ${to}`;
    if (from) return `From ${from}`;
    if (to) return `Until ${to}`;
    return "All Time";
  });

  const isDefault = $derived(!selected && !from && !to);
  const selectedIntervalValue = $derived(
    selected && !from && !to ? selected : "",
  );

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

<FilterShell
  label="Date Range"
  displayText={displayLabel}
  canClear={!isDefault}
  onclear={clear}
  bind:open
>
  {#snippet content()}
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
  {/snippet}
</FilterShell>
