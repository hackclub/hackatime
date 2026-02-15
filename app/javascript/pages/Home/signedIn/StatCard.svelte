<script lang="ts">
  let {
    label,
    value,
    highlight = false,
    subtitle = "",
  }: {
    label: string;
    value: string | number;
    highlight?: boolean;
    subtitle?: string;
  } = $props();
</script>

<div
  class={`
    relative flex flex-col justify-start p-4 rounded-xl border transition-all duration-200 h-full
    ${subtitle ? "pb-6" : ""}
    ${
      highlight
        ? "bg-primary/10 border-primary/30"
        : "bg-surface-content/5 border-surface-content/10 hover:border-surface-content/20"
    }
  `}
>
  <div
    class="text-secondary/80 text-xs font-medium uppercase tracking-wider mb-2"
  >
    {label}
  </div>
  <div
    class={`font-bold text-surface-content wrap-break-word ${String(value).length > 15 ? "text-lg" : "text-xl"}`}
  >
    {value || "—"}
  </div>
  {#if subtitle}
    <span class="absolute bottom-2 left-4 text-xs text-secondary font-normal opacity-70"
      >{subtitle}</span
    >
  {/if}
</div>
