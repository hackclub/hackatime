<script lang="ts">
  import type { Snippet } from "svelte";

  interface Props {
    n: number;
    title: string;
    children: Snippet;
  }

  let { n, title, children }: Props = $props();
</script>

<div class="flex items-start gap-4">
  <div
    class="flex-shrink-0 w-6 h-6 rounded-full bg-darkless text-surface-content flex items-center justify-center text-xs font-bold mt-0.5"
  >
    {n}
  </div>
  <div class="w-full">
    <p class="font-medium mb-1">{title}</p>
    {@render children()}
  </div>
</div>
