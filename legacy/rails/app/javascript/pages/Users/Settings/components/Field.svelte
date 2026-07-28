<script lang="ts">
  import type { Snippet } from "svelte";

  let {
    wrapperId,
    inputId,
    label,
    error,
    children,
  }: {
    wrapperId?: string;
    inputId?: string;
    label: string;
    error?: string;
    children: Snippet;
  } = $props();
</script>

<div id={wrapperId}>
  <label for={inputId} class="mb-2 block text-sm text-surface-content">
    {label}
  </label>
  {@render children()}
  {#if error}
    <p class="mt-2 text-xs text-red">{error}</p>
  {/if}
</div>
