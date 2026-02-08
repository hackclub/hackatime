<script lang="ts">
  let {
    label,
    value,
    large = false,
  }: {
    label: string;
    value: string | number;
    large?: boolean;
  } = $props();
</script>

<div class="bg-dark border border-primary rounded-xl p-4">
  <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
    {label}
  </div>
  <div
    class={`font-semibold text-white ${large ? "text-2xl" : "text-lg"}`}
  >
    {value || "—"}
  </div>
</div>
