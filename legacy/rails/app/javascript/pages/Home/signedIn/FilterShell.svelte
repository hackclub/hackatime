<script lang="ts">
  import { Popover } from "bits-ui";
  import Button from "../../../components/Button.svelte";
  import type { Snippet } from "svelte";
  import { Icon, ChevronDown } from "svelte-hero-icons";
  import type { IconSource } from "svelte-hero-icons";

  let {
    label,
    displayText,
    placeholderText = false,
    canClear = false,
    showLabel = true,
    leadingIcon,
    open = $bindable(false),
    onclear,
    content,
  }: {
    label: string;
    displayText: string;
    placeholderText?: boolean;
    canClear?: boolean;
    showLabel?: boolean;
    leadingIcon?: IconSource;
    open?: boolean;
    onclear?: () => void;
    content: Snippet;
  } = $props();
</script>

<div class="filter relative min-w-0">
  {#if showLabel}
    <span
      class="mb-1.5 block text-xs font-medium uppercase tracking-wider text-secondary/80"
    >
      {label}
    </span>
  {/if}

  <Popover.Root bind:open>
    <div
      class="group m-0 flex min-w-0 items-center rounded-lg border border-surface-200 bg-surface-100 p-0 transition-all duration-200 hover:border-surface-300 hover:bg-surface-200 focus-within:border-primary/70 focus-within:ring-2 focus-within:ring-primary/35 focus-within:ring-offset-1 focus-within:ring-offset-surface"
    >
      <Popover.Trigger>
        {#snippet child({ props })}
          <Button
            type="button"
            unstyled
            class="m-0 flex min-w-0 flex-1 cursor-pointer select-none items-center justify-between border-0 bg-transparent px-3 py-2.5 text-sm text-surface-content"
            {...props}
          >
            <span class="flex min-w-0 items-center gap-2">
              {#if leadingIcon}
                <Icon
                  src={leadingIcon}
                  size="16"
                  class="shrink-0 text-secondary/60"
                />
              {/if}
              <span
                class="truncate font-medium {placeholderText
                  ? 'text-surface-content/60'
                  : ''}"
              >
                {displayText}
              </span>
            </span>
            <Icon
              src={ChevronDown}
              size="16"
              class="text-secondary/60 transition-all duration-200 group-hover:text-secondary {open
                ? 'rotate-180 text-primary'
                : ''}"
            />
          </Button>
        {/snippet}
      </Popover.Trigger>

      {#if canClear}
        <Button
          type="button"
          unstyled
          class="m-0 cursor-pointer border-0 border-l border-surface-200 bg-transparent px-2.5 py-2 text-sm leading-none text-secondary/60 transition-colors duration-150 hover:bg-red/10 hover:text-red"
          onclick={onclear}
        >
          ✕
        </Button>
      {/if}
    </div>

    <Popover.Portal>
      <Popover.Content
        sideOffset={8}
        align="start"
        class="dashboard-select-popover z-1000 w-[min(22rem,calc(100vw-2rem))] rounded-xl border border-surface-content/20 bg-darkless/95 p-2 shadow-xl shadow-black/50 outline-none backdrop-blur-sm"
      >
        {@render content()}
      </Popover.Content>
    </Popover.Portal>
  </Popover.Root>
</div>
