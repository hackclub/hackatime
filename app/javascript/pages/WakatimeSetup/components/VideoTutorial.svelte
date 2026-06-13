<script lang="ts">
  import type { Snippet } from "svelte";
  import { Icon, ChevronRight } from "svelte-hero-icons";

  interface Props {
    label?: string;
    src?: string;
    iframeTitle?: string;
    children?: Snippet;
  }

  let {
    label = "Watch video tutorial",
    src,
    iframeTitle,
    children,
  }: Props = $props();
</script>

<div class="pt-4 border-t border-darkless">
  <details class="group">
    <summary
      class="cursor-pointer text-sm text-secondary hover:text-surface-content flex items-center gap-2 transition-colors"
    >
      <Icon
        src={ChevronRight}
        size="16"
        class="transition-transform group-open:rotate-90"
      />
      {label}
    </summary>
    {#if children}
      <div class="mt-4 pl-6">{@render children()}</div>
    {:else if src}
      <div class="mt-4 rounded-lg overflow-hidden border border-darkless">
        <iframe
          title={iframeTitle ?? label}
          width="100%"
          height="300"
          {src}
          frameborder="0"
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
          allowfullscreen
        ></iframe>
      </div>
    {/if}
  </details>
</div>
