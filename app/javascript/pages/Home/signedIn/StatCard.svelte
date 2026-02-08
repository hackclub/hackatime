<script lang="ts">
  let {
    label,
    value,
    large = false,
    subtitle = "",
  }: {
    label: string;
    value: string | number;
    large?: boolean;
    subtitle?: string;
  } = $props();
</script>

<div
  class="bg-dark border border-primary rounded-xl p-4 transition-all duration-200 h-full"
>
  <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
    {label}
  </div>
  <div
    class={`font-semibold text-white ${large ? "text-2xl" : "text-lg"}`}
  >
    {value || "—"}
    {#if subtitle}
      <span class="super text-xs text-secondary font-normal ml-1"
        >{subtitle}</span
      >
    {/if}
  </div>
</div>
