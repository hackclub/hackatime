<script lang="ts">
  import { Checkbox } from "bits-ui";
  import type { Snippet } from "svelte";

  let {
    name,
    checked = $bindable(false),
    label,
    description,
    disabled = false,
    includeHidden = true,
    align = "center",
    children,
  }: {
    name: string;
    checked?: boolean;
    label?: string;
    description?: string;
    disabled?: boolean;
    includeHidden?: boolean;
    align?: "center" | "start";
    children?: Snippet;
  } = $props();
</script>

<label
  class={`flex ${align === "start" ? "items-start" : "items-center"} gap-3 text-sm text-surface-content`}
>
  {#if includeHidden && !disabled}
    <input type="hidden" {name} value="0" />
  {/if}
  <Checkbox.Root
    bind:checked
    name={disabled ? undefined : name}
    value="1"
    {disabled}
    class={`${align === "start" ? "mt-0.5" : ""} inline-flex h-4 w-4 min-w-4 items-center justify-center rounded border border-surface-200 bg-darker text-on-primary transition-colors data-[state=checked]:border-primary data-[state=checked]:bg-primary data-[disabled]:opacity-50`}
  >
    {#snippet children({ checked: isChecked })}
      <span class={isChecked ? "text-[10px]" : "hidden"}>✓</span>
    {/snippet}
  </Checkbox.Root>
  {#if children}
    {@render children()}
  {:else if description}
    <span class="flex flex-col gap-1">
      <span>{label}</span>
      <span class="text-xs text-muted">{description}</span>
    </span>
  {:else}
    {label}
  {/if}
</label>
