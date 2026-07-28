<script lang="ts">
  let {
    text,
    size = "xs",
    class: className = "",
  }: { text: string; size?: "xs" | "sm"; class?: string } = $props();
</script>

<pre
  class={`overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 text-${size} text-surface-content ${className}`}>{text}</pre>
