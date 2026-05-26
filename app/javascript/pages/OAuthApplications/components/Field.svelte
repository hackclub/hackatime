<script lang="ts">
  let {
    label,
    children,
  }: { label: string; children: import("svelte").Snippet } = $props();
</script>

<div>
  <p class="mb-1 text-xs uppercase tracking-wide text-muted">{label}</p>
  {@render children()}
</div>
