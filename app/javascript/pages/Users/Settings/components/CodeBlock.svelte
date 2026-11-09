<script lang="ts">
  const sizeClasses = {
    xs: "text-xs",
    sm: "text-sm",
  } as const;

  let {
    text,
    size = "xs",
    class: className = "",
  }: {
    text: string;
    size?: keyof typeof sizeClasses;
    class?: string;
  } = $props();
</script>

<pre
  class={`overflow-x-auto rounded-md border border-surface-200 bg-darker p-4 ${sizeClasses[size]} text-surface-content ${className}`}>{text}</pre>
