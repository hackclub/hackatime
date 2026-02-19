<script lang="ts">
  import { Popover } from "bits-ui";
  import Button from "./Button.svelte";

  type Option = {
    label: string;
    value: string;
  };

  let {
    label,
    placeholder = "Select...",
    emptyText = "No results",
    options = [],
    selected = $bindable<string[]>([]),
  }: {
    label: string;
    placeholder?: string;
    emptyText?: string;
    options: Option[];
    selected?: string[];
  } = $props();

  let open = $state(false);
  let search = $state("");

  const filtered = $derived(
    options.filter((option) =>
      option.label.toLowerCase().includes(search.trim().toLowerCase()),
    ),
  );

  function toggle(value: string) {
    if (selected.includes(value)) {
      selected = selected.filter((entry) => entry !== value);
      return;
    }

    selected = [...selected, value];
  }

  function remove(value: string, event: MouseEvent) {
    event.stopPropagation();
    selected = selected.filter((entry) => entry !== value);
  }

  $effect(() => {
    if (!open) {
      search = "";
    }
  });
</script>

<div class="relative">
  <p class="mb-1 text-xs font-medium text-muted">{label}</p>

  <Popover.Root bind:open>
    <Popover.Trigger>
      {#snippet child({ props })}
        <div
          {...props}
          class="group min-h-10 cursor-pointer rounded-md border border-surface-200 bg-darker px-3 py-2 transition-all duration-200 hover:border-surface-300 focus-within:border-primary/70 focus-within:ring-2 focus-within:ring-primary/35 focus-within:ring-offset-1 focus-within:ring-offset-surface"
        >
          {#if selected.length === 0}
            <div class="flex items-center justify-between gap-2">
              <p class="text-sm text-muted">{placeholder}</p>
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
            </div>
          {:else}
            <div class="flex flex-wrap items-center gap-1.5">
              {#each selected as value}
                <span
                  class="inline-flex items-center gap-1 rounded-full border border-primary/30 bg-primary/10 px-2 py-1 text-xs font-medium text-surface-content"
                >
                  {options.find((option) => option.value === value)?.label ||
                    value}
                  <Button
                    type="button"
                    unstyled
                    class="text-muted hover:text-surface-content"
                    onclick={(event: MouseEvent) => remove(value, event)}
                  >
                    ×
                  </Button>
                </span>
              {/each}
            </div>
          {/if}
        </div>
      {/snippet}
    </Popover.Trigger>

    <Popover.Portal>
      <Popover.Content
        sideOffset={8}
        align="start"
        class="dashboard-select-popover z-[11000] w-[min(28rem,calc(100vw-2rem))] rounded-xl border border-surface-content/20 bg-darkless/95 p-2 shadow-xl shadow-black/50 outline-none backdrop-blur-sm"
      >
        <input
          type="text"
          bind:value={search}
          {placeholder}
          class="mb-2 h-10 w-full rounded-lg border border-surface-content/20 bg-dark px-3 text-sm text-surface-content placeholder:text-secondary/60 transition-colors duration-150 focus:border-primary/70 focus:outline-none focus:ring-2 focus:ring-primary/45 focus:ring-offset-1 focus:ring-offset-dark"
        />

        <div
          class="max-h-52 overflow-y-auto rounded-lg border border-surface-content/15 bg-dark/55 p-1"
        >
          {#if filtered.length > 0}
            {#each filtered as option}
              {@const isSelected = selected.includes(option.value)}
              <Button
                type="button"
                unstyled
                class={`flex w-full items-center justify-between rounded-md px-3 py-2 text-left text-sm transition-all duration-150 ${
                  isSelected
                    ? "bg-primary/15 text-surface-content font-medium border-l-2 border-primary"
                    : "text-muted hover:bg-surface-100/60 hover:text-surface-content border-l-2 border-transparent"
                }`}
                onclick={() => toggle(option.value)}
              >
                <span class="truncate">{option.label}</span>
                {#if isSelected}
                  <span
                    class="flex h-5 w-5 items-center justify-center rounded-full bg-primary text-[10px] font-bold text-on-primary"
                    >✓</span
                  >
                {/if}
              </Button>
            {/each}
          {:else}
            <p class="px-3 py-2 text-sm text-secondary/60">{emptyText}</p>
          {/if}
        </div>
      </Popover.Content>
    </Popover.Portal>
  </Popover.Root>
</div>
