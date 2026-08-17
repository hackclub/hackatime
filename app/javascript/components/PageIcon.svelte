<script lang="ts">
  type Icon = "check" | "monitor";

  let { name, class: className = "" }: { name: Icon; class?: string } =
    $props();

  const paths: Record<Icon, string[]> = {
    check: ["M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"],
    monitor: [
      "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z",
    ],
  };
</script>

<svg
  class={className}
  fill="none"
  stroke="currentColor"
  stroke-width="2"
  viewBox="0 0 24 24"
  aria-hidden="true"
>
  {#each paths[name] as d}<path
      {d}
      stroke-linecap="round"
      stroke-linejoin="round"
    />{/each}
</svg>
