<script lang="ts">
  import type InertiaDocsNotFoundProps from "../../types/serializers/Inertia/DocsNotFoundProps";
  import { staticPages } from "../../api";

  let {
    status_code = 404,
    title = "Page Not Found",
    message = "The page you were looking for doesn't exist.",
  }: Partial<InertiaDocsNotFoundProps> = $props();
</script>

<svelte:head>
  <title>{title} - Hackatime</title>
</svelte:head>

<div class="min-h-screen text-white flex items-center justify-center">
  <div class="max-w-xl mx-auto px-6 py-8 text-center">
    <div class="bg-dark rounded-lg p-8">
      <h1 class="text-6xl font-bold text-primary mb-4">{status_code}</h1>
      <h2 class="text-2xl font-semibold text-white mb-4">{title}</h2>
      <p class="text-secondary mb-8">{message}</p>
      <a
        href={staticPages.index.path()}
        class="inline-flex items-center justify-center px-6 py-3 rounded-lg bg-primary text-white font-medium hover:brightness-110 transition-all"
      >
        Go Home
      </a>
    </div>
  </div>
</div>
