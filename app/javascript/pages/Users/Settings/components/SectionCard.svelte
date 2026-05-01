<script lang="ts">
  import type { Snippet } from "svelte";

  type Tone = "default" | "danger";

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
    tone?: Tone;
    wide?: boolean;
    hasBody?: boolean;
    footerClass?: string;
    children?: Snippet;
    footer?: Snippet;
  } = $props();

  const toneClasses = $derived(
    tone === "danger"
      ? "bg-danger/5 shadow-[inset_0_0_0_1px_rgba(200,57,79,0.35),0_16px_36px_rgba(0,0,0,0.12)]"
      : "bg-surface shadow-[inset_0_0_0_1px_rgba(255,255,255,0.08),0_16px_36px_rgba(0,0,0,0.12)]",
  );
  const contentWidth = $derived(wide ? "" : "max-w-2xl");
  const descriptionWidth = $derived(wide ? "max-w-3xl" : "max-w-2xl");
</script>

<section
  {id}
  data-settings-card
  data-settings-card-tone={tone}
  class={`scroll-mt-24 overflow-hidden rounded-2xl ${toneClasses}`}
>
  <div
    class="px-5 py-4 shadow-[inset_0_-1px_0_rgba(255,255,255,0.08)] sm:px-6 sm:py-5"
  >
    <div class={descriptionWidth}>
      <h2
        class="text-balance text-xl font-semibold tracking-tight text-surface-content"
      >
        {title}
      </h2>
      <p class="mt-1 text-pretty text-sm leading-6 text-muted">
        {description}
      </p>
    </div>
  </div>

  {#if hasBody}
    <div class="px-5 py-4 sm:px-6 sm:py-5">
      <div class={contentWidth}>
        {@render children?.()}
      </div>
    </div>
  {/if}

  {#if footer}
    <div
      data-settings-footer
      class={`bg-surface-100/60 px-5 py-3.5 shadow-[inset_0_1px_0_rgba(255,255,255,0.08)] sm:px-6 sm:py-4 ${footerClass}`}
    >
      {@render footer()}
    </div>
  {/if}
</section>
