<script lang="ts">
  type Tone = "green" | "red";
  let {
    tone,
    iconPath,
    title,
    description,
    children,
  }: {
    tone?: Tone;
    iconPath?: string;
    title: string;
    description?: string;
    children?: import("svelte").Snippet;
  } = $props();

  const tones: Record<Tone, string> = {
    green: "bg-green/10 text-green",
    red: "bg-red/10 text-red",
  };
</script>

<div class="flex min-h-screen w-screen items-center justify-center p-4">
  <div class="w-full max-w-md">
    <div class="mb-6 text-center">
      {#if tone && iconPath}
        <div
          class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl {tones[
            tone
          ]}"
        >
          <svg
            class="h-8 w-8"
            fill="none"
            stroke="currentColor"
            stroke-width="1.5"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" d={iconPath} />
          </svg>
        </div>
      {/if}
      <h1 class="text-2xl font-bold text-surface-content">{title}</h1>
      {#if description}
        <p class="mt-2 text-sm text-muted">{description}</p>
      {/if}
    </div>
    {@render children?.()}
  </div>
</div>
