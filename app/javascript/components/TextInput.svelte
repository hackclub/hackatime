<script lang="ts">
  import type { HTMLInputAttributes } from "svelte/elements";

  let {
    value = $bindable(),
    class: className,
    ...rest
  }: HTMLInputAttributes = $props();

  const defaultClass =
    "w-full rounded-md border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content focus:border-primary focus:outline-none";
</script>

<input bind:value class={className || defaultClass} {...rest} />
