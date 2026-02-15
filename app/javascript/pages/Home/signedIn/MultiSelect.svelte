<script lang="ts">
  let {
    label,
    param,
    values,
    selected,
    onchange,
  }: {
    label: string;
    param: string;
    values: string[];
    selected: string[];
    onchange: (selected: string[]) => void;
  } = $props();

  let open = $state(false);
  let search = $state("");
  let container: HTMLDivElement | undefined = $state();

  let filtered = $derived(
    search
      ? values.filter((v) => v.toLowerCase().includes(search.toLowerCase()))
      : values,
  );

  let displayText = $derived(
    selected.length === 0
      ? `Filter by ${label}...`
      : selected.length === 1
        ? selected[0]
        : `${selected.length} selected`,
  );

  function toggle(value: string) {
    if (selected.includes(value)) {
      onchange(selected.filter((s) => s !== value));
    } else {
      onchange([...selected, value]);
    }
  }

  function clear(e: MouseEvent) {
    e.stopPropagation();
    onchange([]);
  }

  function handleClickOutside(e: MouseEvent) {
    if (container && !container.contains(e.target as Node)) {
      open = false;
    }
  }

  $effect(() => {
    if (open) {
      document.addEventListener("click", handleClickOutside, true);
      return () =>
        document.removeEventListener("click", handleClickOutside, true);
    }
  });

  $effect(() => {
    if (!open) {
      search = "";
    }
  });
</script>

<div class="filter relative" bind:this={container}>
  <span class="block text-xs font-medium mb-1.5 text-secondary/80 uppercase tracking-wider">
    {label}
  </span>

  <div class="group flex items-center border border-surface-content/20 rounded-lg bg-surface-100 m-0 p-0 transition-all duration-200 hover:border-surface-content/30 hover:bg-surface-200">
    <button
      type="button"
      class="flex-1 px-3 py-2.5 text-sm cursor-pointer select-none text-surface-content m-0 bg-transparent flex items-center justify-between border-0 min-w-0"
      onclick={() => (open = !open)}
    >
      <span class="truncate {selected.length === 0 ? 'text-surface-content/60' : ''}">
        {displayText}
      </span>
      <svg
        class={`w-4 h-4 text-secondary/60 transition-transform duration-200 group-hover:text-secondary ${open ? "rotate-180" : ""}`}
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
      </svg>
    </button>

    {#if selected.length > 0}
      <button
        type="button"
        class="px-2.5 py-2 text-sm leading-none text-secondary/60 bg-transparent border-0 border-l border-surface-content/10 cursor-pointer m-0 hover:text-red hover:bg-red/10 transition-colors duration-150"
        onclick={clear}
      >
        ×
      </button>
    {/if}
  </div>

  {#if open}
    <div class="absolute top-full left-0 right-0 min-w-64 bg-darkless border border-surface-content/10 rounded-lg mt-2 shadow-xl shadow-black/50 z-1000 p-2">
      <input
        type="text"
        placeholder="Search..."
        class="w-full border border-surface-content/10 px-3 py-2.5 mb-2 bg-dark text-surface-content text-sm rounded-md h-auto placeholder:text-secondary/60 focus:outline-none focus:border-surface-content/20"
        bind:value={search}
      />

      <div class="overflow-y-auto m-0 max-h-64">
        {#each filtered as value}
          <label class="flex items-center px-3 py-2.5 cursor-pointer text-sm text-muted m-0 bg-transparent rounded-md hover:bg-dark transition-colors duration-150">
            <input
              type="checkbox"
              checked={selected.includes(value)}
              onchange={() => toggle(value)}
              class="mr-3 mb-0 h-4 w-4 min-w-4 appearance-none border border-surface-content/20 rounded bg-dark relative cursor-pointer p-0 checked:bg-primary checked:border-primary hover:border-surface-content/40 transition-colors duration-150"
            />
            {value}
          </label>
        {/each}

        {#if filtered.length === 0}
          <div class="px-3 py-2.5 text-sm text-secondary/60">No results</div>
        {/if}
      </div>
    </div>
  {/if}
</div>
