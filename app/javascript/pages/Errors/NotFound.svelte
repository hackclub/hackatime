<script lang="ts">
  import Button from "../../components/Button.svelte";

  let {
    status_code = 404,
    title = "Page Not Found",
    message = "The page you were looking for doesn't exist.",
  }: {
    status_code?: number;
    title?: string;
    message?: string;
  } = $props();
</script>

<svelte:head>
  <title>{title} - Hackatime</title>
</svelte:head>

<div class="min-h-screen text-surface-content flex items-center justify-center">
  <div class="max-w-xl mx-auto px-6 py-8 text-center">
    <div class="bg-dark rounded-lg p-8">
      <h1 class="text-6xl font-bold text-primary mb-4">{status_code}</h1>
      <h2 class="text-2xl font-semibold text-surface-content mb-4">{title}</h2>
      <p class="text-secondary mb-8">{message}</p>
      <Button href="/" size="lg" class="hover:brightness-110 transition-all">
        Go Home
      </Button>
    </div>
  </div>
</div>
