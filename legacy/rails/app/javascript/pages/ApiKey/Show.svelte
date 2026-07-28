<script lang="ts">
  let { api_key }: { api_key: string } = $props();

  let copied = $state(false);

  const copyApiKey = async () => {
    await navigator.clipboard.writeText(api_key);
    copied = true;
    setTimeout(() => (copied = false), 3000);
  };
</script>

<svelte:head>
  <title>Your API Key - Hackatime</title>
</svelte:head>

<div class="mx-auto flex w-full max-w-5xl flex-col items-center px-4 py-12">
  <header class="mb-8 text-center">
    <h1
      class="text-3xl sm:text-4xl font-bold tracking-tight text-surface-content"
    >
      Your API Key
    </h1>
    <p class="mt-2 text-muted text-pretty">
      Click the box below to copy it to your clipboard.
    </p>
  </header>

  <div class="group relative w-full transition-transform active:scale-[0.99]">
    <input
      type="text"
      readonly
      value={api_key}
      onclick={(e) => {
        e.currentTarget.select();
        copyApiKey();
      }}
      class="monospace w-full rounded-3xl border-2 border-surface-200 bg-darker px-6 py-8 sm:px-10 sm:py-12 text-center text-xl sm:text-3xl md:text-4xl font-bold text-surface-content cursor-pointer transition-colors hover:border-primary hover:bg-dark focus:border-primary focus:outline-none focus:ring-4 focus:ring-primary/30"
    />

    <div
      class="pointer-events-none absolute top-4 right-4 rounded-full bg-surface-200/60 px-3 py-1 text-xs font-semibold uppercase tracking-wide text-muted transition-colors group-hover:bg-primary/20 group-hover:text-primary"
    >
      {copied ? "Copied!" : "Click to copy"}
    </div>
  </div>

  <p class="mt-6 text-center text-sm text-muted">
    Keep this key secret. Anyone with this key can submit heartbeats as you.
  </p>
</div>
