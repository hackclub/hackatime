<script lang="ts">
  let {
    label,
    value,
    detail,
  }: {
    label: string;
    value: string;
    detail?: string;
  } = $props();
</script>

<article class="stat-card">
  <p>{label}</p>
  <strong>{value}</strong>
  {#if detail}<span>{detail}</span>{/if}
</article>
