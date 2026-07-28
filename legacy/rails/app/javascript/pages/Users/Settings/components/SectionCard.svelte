<script lang="ts">
  import type { Snippet } from "svelte";

  let {
    id,
    title,
    description,
    tone = "default",
    wide = false,
    hasBody = true,
    footerClass = "flex items-center justify-end gap-3",
    children,
    footer,
  }: {
    id?: string;
    title: string;
    description: string;
    tone?: "default" | "danger";
    wide?: boolean;
    hasBody?: boolean;
    footerClass?: string;
    children?: Snippet;
    footer?: Snippet;
  } = $props();

  const widthClass = $derived(wide ? "" : "max-w-2xl");
  const descWidthClass = $derived(wide ? "max-w-3xl" : "max-w-2xl");
</script>

<section
  {id}
  data-settings-card
  data-settings-card-tone={tone}
  class={`scroll-mt-24 overflow-hidden rounded-2xl ${tone === "danger" ? "bg-danger/5" : "bg-surface"}`}
>
  <div data-settings-card-header class="px-5 py-4 sm:px-6 sm:py-5">
    <div class={descWidthClass}>
      <h2
        class="text-balance text-xl font-semibold tracking-tight text-surface-content"
      >
        {title}
      </h2>
      <p class="mt-1 text-pretty text-sm leading-6 text-muted">{description}</p>
    </div>
  </div>

  {#if hasBody}
    <div class="px-5 py-4 sm:px-6 sm:py-5">
      <div class={widthClass}>{@render children?.()}</div>
    </div>
  {/if}

  {#if footer}
    <div
      data-settings-footer
      class={`bg-surface-100/60 px-5 py-3.5 sm:px-6 sm:py-4 ${footerClass}`}
    >
      {@render footer()}
    </div>
  {/if}
</section>
