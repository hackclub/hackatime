<script lang="ts">
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
  let container: HTMLDivElement | undefined = $state();

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

  function handleClickOutside(e: MouseEvent) {
    if (container && !container.contains(e.target as Node)) {
      open = false;
    }
  }

  $effect(() => {
    if (open) {
      document.addEventListener("click", handleClickOutside, true);
      return () => document.removeEventListener("click", handleClickOutside, true);
    }
  });

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

<div class="filter relative" bind:this={container}>
  <span class="block text-xs font-medium mb-1.5 text-secondary/80 uppercase tracking-wider">
    Date Range
  </span>

  <div class="group flex items-center border border-white/20 rounded-lg bg-surface-100 m-0 p-0 transition-all duration-200 hover:border-white/30 hover:bg-surface-200">
    <button
      type="button"
      class="flex-1 px-3 py-2.5 text-sm cursor-pointer select-none text-white m-0 bg-transparent flex items-center justify-between border-0"
      onclick={() => (open = !open)}
    >
      <span>{displayLabel}</span>
      <svg class="w-4 h-4 text-secondary/60 transition-transform duration-200 group-hover:text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
      </svg>
    </button>

    {#if !isDefault}
      <button
        type="button"
        class="px-2.5 py-2 text-sm leading-none text-secondary/60 bg-transparent border-0 border-l border-white/10 cursor-pointer m-0 hover:text-red hover:bg-red/10 transition-colors duration-150"
        onclick={clear}
      >
        ✕
      </button>
    {/if}
  </div>

  {#if open}
    <div class="absolute top-full left-0 right-0 min-w-64 bg-darkless border border-white/10 rounded-lg mt-2 shadow-xl shadow-black/50 z-1000 p-2">
      <div class="overflow-y-auto m-0 max-h-56">
        {#each INTERVALS as interval}
          <label class="flex items-center px-3 py-2.5 cursor-pointer text-sm text-gray-300 m-0 bg-transparent rounded-md hover:bg-dark transition-colors duration-150">
            <input
              type="radio"
              name="interval"
              class="mr-3 mb-0 h-4 w-4 min-w-4 appearance-none border border-white/20 rounded-full bg-dark relative cursor-pointer p-0 checked:bg-primary checked:border-primary hover:border-white/40 transition-colors duration-150"
              checked={selected === interval.key && !from && !to}
              onchange={() => selectInterval(interval.key)}
            />
            {interval.label}
          </label>
        {/each}
      </div>

      <hr class="my-2 border-white/10" />

      <div class="flex flex-col gap-2.5 pt-1">
        <label class="flex items-center justify-between text-sm text-gray-300">
          <span class="text-secondary/80">Start</span>
          <input
            type="date"
            class="ml-2 py-2 px-3 bg-dark border border-white/10 rounded-md text-sm text-gray-200 focus:outline-none focus:border-white/20 transition-colors duration-150"
            bind:value={customFrom}
          />
        </label>
        <label class="flex items-center justify-between text-sm text-gray-300">
          <span class="text-secondary/80">End</span>
          <input
            type="date"
            class="ml-2 py-2 px-3 bg-dark border border-white/10 rounded-md text-sm text-gray-200 focus:outline-none focus:border-white/20 transition-colors duration-150"
            bind:value={customTo}
          />
        </label>
        <button
          type="button"
          class="px-3 py-2.5 mt-1 rounded-md font-medium text-sm transition-all duration-200 cursor-pointer bg-primary text-white hover:bg-primary/90 border-0"
          onclick={applyCustomRange}
        >
          Apply
        </button>
      </div>
    </div>
  {/if}
</div>
