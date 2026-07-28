<script lang="ts">
  let {
    items,
    empty,
    variant = "scope",
  }: {
    items: string[];
    empty: string;
    variant?: "scope" | "uri";
  } = $props();

  const cls = $derived(
    variant === "scope"
      ? "rounded-md border border-primary/30 bg-primary/10 px-2 py-0.5 font-mono text-xs text-primary"
      : "max-w-full truncate rounded-md border border-surface-200 bg-darker px-2 py-1 font-mono text-xs text-surface-content",
  );
</script>

{#if items.length > 0}
  <div class="flex flex-wrap gap-1.5">
    {#each items as item}
      <span class={cls}>{item}</span>
    {/each}
  </div>
{:else}
  <p class="text-sm text-muted">{empty}</p>
{/if}
