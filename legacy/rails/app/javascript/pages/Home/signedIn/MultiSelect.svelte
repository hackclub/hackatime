<script lang="ts">
  import { Checkbox } from "bits-ui";
  import FilterShell from "./FilterShell.svelte";

  let {
    label,
    values,
    selected,
    onchange,
  }: {
    label: string;
    param?: string;
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

  $effect(() => {
    if (!open) search = "";
  });
</script>

<FilterShell
  {label}
  {displayText}
  placeholderText={selected.length === 0}
  canClear={selected.length > 0}
  onclear={() => onchange([])}
  bind:open
>
  {#snippet content()}
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
                class="mr-3 inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border text-[10px] font-bold transition-all duration-150 {checked
                  ? 'border-primary bg-primary text-on-primary'
                  : 'border-surface-content/35 bg-surface/40 text-transparent'}"
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
  {/snippet}
</FilterShell>
