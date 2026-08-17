<script lang="ts">
  import type { Snippet } from "svelte";

  type Variant =
    | "eyebrow"
    | "secondary"
    | "muted"
    | "mutedMedium"
    | "mutedSpaced"
    | "heading";

  let {
    label,
    class: className = "",
    variant = "eyebrow",
    children,
  }: {
    label: string;
    class?: string;
    variant?: Variant;
    children: Snippet;
  } = $props();

  const labelClasses: Record<Variant, string> = {
    eyebrow: "mb-1 text-xs uppercase tracking-wide text-muted",
    secondary: "mb-2 block text-sm font-medium text-secondary",
    muted: "mb-1 block text-sm font-medium text-muted",
    mutedMedium: "mb-2 block text-md font-medium text-muted",
    mutedSpaced: "mb-2 text-sm font-medium text-muted",
    heading: "mb-2 block text-md font-bold text-surface-content",
  };
</script>

<div class={className}>
  <p class={labelClasses[variant]}>{label}</p>
  {@render children()}
</div>
