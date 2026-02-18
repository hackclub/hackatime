<script lang="ts">
  import { Select as BitsSelect } from "bits-ui";

  type SelectItem = {
    value: string;
    label: string;
    disabled?: boolean;
  };

  let {
    id,
    name,
    value = $bindable(""),
    items = [],
    placeholder = "Select an option",
    allowDeselect = false,
    disabled = false,
    class: className = "",
  }: {
    id?: string;
    name?: string;
    value?: string;
    items: SelectItem[];
    placeholder?: string;
    allowDeselect?: boolean;
    disabled?: boolean;
    class?: string;
  } = $props();

  const selectedLabel = $derived(
    items.find((item) => item.value === value)?.label ?? placeholder,
  );
</script>

<BitsSelect.Root
  type="single"
  bind:value={value as never}
  {name}
  {allowDeselect}
  {disabled}
  {items}
>
  <BitsSelect.Trigger
    {id}
    class={`inline-flex w-full items-center justify-between rounded-md border border-surface-200 bg-darker px-3 py-2 text-left text-sm text-surface-content transition-all duration-200 hover:border-surface-300 focus-visible:border-primary/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/45 focus-visible:ring-offset-2 focus-visible:ring-offset-surface data-[placeholder]:text-surface-content/60 ${className}`}
  >
    <span class="truncate">{selectedLabel}</span>
    <svg
      class="ml-2 h-4 w-4 shrink-0 text-secondary/70"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M19 9l-7 7-7-7"
      ></path>
    </svg>
  </BitsSelect.Trigger>

  <BitsSelect.Portal>
    <BitsSelect.Content
      align="start"
      sideOffset={6}
      class="dashboard-select-popover z-1000 w-[min(22rem,calc(100vw-2rem))] rounded-xl border border-surface-content/20 bg-darkless/95 p-2 shadow-xl shadow-black/50 outline-none backdrop-blur-sm"
    >
      <BitsSelect.Viewport
        class="max-h-64 overflow-y-auto rounded-lg border border-surface-content/15 bg-dark/55 p-1"
      >
        {#each items as item}
          <BitsSelect.Item
            value={item.value}
            label={item.label}
            disabled={item.disabled}
            class="flex w-full select-none items-center justify-between rounded-md px-3 py-2 text-sm text-surface-content outline-none transition-all duration-150 hover:bg-surface-100/60 data-[highlighted]:bg-surface-100/70 data-[state=checked]:bg-primary/12 data-[disabled]:cursor-not-allowed data-[disabled]:opacity-50"
          >
            {#snippet children({ selected })}
              <span class="truncate">{item.label}</span>
              {#if selected}
                <span class="ml-2 text-primary">✓</span>
              {/if}
            {/snippet}
          </BitsSelect.Item>
        {/each}
      </BitsSelect.Viewport>
    </BitsSelect.Content>
  </BitsSelect.Portal>
</BitsSelect.Root>
