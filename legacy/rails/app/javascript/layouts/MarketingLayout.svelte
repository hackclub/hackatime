<script lang="ts">
  import type { Snippet } from "svelte";
  import { DEFAULT_THEME } from "../utils";

  let { children }: { children?: Snippet } = $props();

  $effect(() => {
    const html = document.documentElement;
    const previousTheme = html.getAttribute("data-theme");
    html.setAttribute("data-theme", DEFAULT_THEME);
    document
      .querySelector("meta[name='color-scheme']")
      ?.setAttribute("content", "dark");
    return () => {
      if (previousTheme) html.setAttribute("data-theme", previousTheme);
    };
  });
</script>

{@render children?.()}
