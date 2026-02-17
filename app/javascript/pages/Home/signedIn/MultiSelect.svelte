<script lang="ts">
  import { Checkbox, Popover } from "bits-ui";
  import Button from "../../../components/Button.svelte";

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

  function clear(e: MouseEvent) {
    e.stopPropagation();
    onchange([]);
  }

  $effect(() => {
    if (!open) {
      search = "";
    }
  });
</script>

<div class="filter relative">
  <span
    class="block text-xs font-medium mb-1.5 text-secondary/80 uppercase tracking-wider"
  >
    {label}
  </span>

  <Popover.Root bind:open>
    <div
      class="group m-0 flex items-center rounded-lg border border-surface-200 bg-surface-100 p-0 transition-all duration-200 hover:border-surface-300 hover:bg-surface-200 focus-within:border-primary/70 focus-within:ring-2 focus-within:ring-primary/35 focus-within:ring-offset-1 focus-within:ring-offset-surface"
    >
      <Popover.Trigger>
        {#snippet child({ props })}
          <Button
            type="button"
            unstyled
            class="m-0 flex min-w-0 flex-1 cursor-pointer select-none items-center justify-between border-0 bg-transparent px-3 py-2.5 text-sm text-surface-content"
            {...props}
          >
            <span
              class="truncate font-medium {selected.length === 0
                ? 'text-surface-content/60'
                : ''}"
            >
              {displayText}
            </span>
            <svg
              class={`h-4 w-4 text-secondary/60 transition-all duration-200 group-hover:text-secondary ${open ? "rotate-180 text-primary" : ""}`}
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M19 9l-7 7-7-7"
              />
            </svg>
          </Button>
        {/snippet}
      </Popover.Trigger>

      {#if selected.length > 0}
        <Button
          type="button"
          unstyled
          class="m-0 cursor-pointer border-0 border-l border-surface-200 bg-transparent px-2.5 py-2 text-sm leading-none text-secondary/60 transition-colors duration-150 hover:bg-red/10 hover:text-red"
          onclick={clear}
        >
          ×
        </Button>
      {/if}
    </div>

    <Popover.Portal>
      <Popover.Content
        sideOffset={8}
        align="start"
        class="dashboard-select-popover z-1000 w-[min(22rem,calc(100vw-2rem))] rounded-xl border border-surface-content/20 bg-darkless/95 p-2 shadow-xl shadow-black/50 outline-none backdrop-blur-sm"
      >
        <input
          type="text"
          placeholder="Search..."
          class="mb-2 h-10 w-full rounded-lg border border-surface-content/20 bg-dark px-3 text-sm text-surface-content placeholder:text-secondary/60 transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark"
          bind:value={search}
        />

        <div
          class="m-0 max-h-64 overflow-y-auto rounded-lg border border-surface-content/15 bg-dark/55 p-1"
        >
          <Checkbox.Group
            value={selected}
            onValueChange={(next) => onchange(next as string[])}
            class="flex flex-col"
          >
            {#each filtered as value}
              <Checkbox.Root
                {value}
                class="flex w-full items-center rounded-md px-3 py-2 text-sm text-muted outline-none transition-all duration-150 hover:bg-surface-100/60 hover:text-surface-content data-[highlighted]:bg-surface-100/70 data-[state=checked]:bg-primary/12 data-[state=checked]:text-surface-content"
              >
                {#snippet children({ checked })}
                  <span
                    class={`mr-3 inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border text-[10px] font-bold transition-all duration-150 ${checked ? "border-primary bg-primary text-on-primary" : "border-surface-content/35 bg-surface/40 text-transparent"}`}
                  >
                    ✓
                  </span>
                  <span class="truncate">{value}</span>
                {/snippet}
              </Checkbox.Root>
            {/each}
          </Checkbox.Group>

          {#if filtered.length === 0}
            <div class="px-3 py-2 text-sm text-secondary/60">No results</div>
          {/if}
        </div>
      </Popover.Content>
    </Popover.Portal>
  </Popover.Root>
</div>
