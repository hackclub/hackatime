<script lang="ts">
  import type { Snippet } from "svelte";

  let {
    id,
    bg = "",
    py = "py-20",
    children,
  }: {
    id?: string;
    bg?: string;
    py?: string;
    children: Snippet;
  } = $props();
</script>

<section class="{py} w-full {bg}" {id}>
  <div class="max-w-[1100px] mx-auto px-6">
    {@render children()}
  </div>
</section>
