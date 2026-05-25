<script lang="ts">
  type Tone = "green" | "primary" | "yellow" | "red";
  let {
    tone = "primary",
    rounded = "full",
    children,
  }: {
    tone?: Tone;
    rounded?: "full" | "md";
    children: import("svelte").Snippet;
  } = $props();

  const tones: Record<Tone, string> = {
    green: "border-green/40 bg-green/15 text-green",
    primary: "border-primary/35 bg-primary/12 text-primary",
    yellow: "border-yellow/40 bg-yellow/15 text-yellow",
    red: "border-red/45 bg-red/15 text-red",
  };
</script>

<span
  class="inline-flex border {tones[tone]} {rounded === 'full'
    ? 'rounded-full px-2 py-0.5'
    : 'rounded-md px-2 py-0.5 font-mono'} text-xs font-semibold"
>
  {@render children()}
</span>
