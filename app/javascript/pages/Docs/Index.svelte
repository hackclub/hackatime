<script lang="ts">
  import type InertiaDocsIndexProps from "../../types/serializers/Inertia/DocsIndexProps";
  import { users } from "../../api";

  let {
    popular_editors,
    all_editors,
  }: InertiaDocsIndexProps = $props();
</script>

<svelte:head>
  <title>Documentation - Hackatime</title>
  <meta
    name="description"
    content="Complete documentation for Hackatime - learn how to track your coding time and use our API."
  />
</svelte:head>

<div class="max-w-4xl mx-auto">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-surface-content mb-2">Documentation</h1>
    <p class="text-muted">
      Free, open-source time tracking for Hack Club. Like WakaTime, but free.
    </p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
    <a
      href={users.wakatimeSetup.path()}
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <div class="text-2xl mb-2">⚡</div>
      <h3 class="font-semibold text-surface-content">Quick Start</h3>
      <p class="text-sm text-muted text-center mt-1">
        Set up in under a minute
      </p>
    </a>

    <a
      href="/docs/getting-started/installation"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <div class="text-2xl mb-2">💻</div>
      <h3 class="font-semibold text-surface-content">Installation</h3>
      <p class="text-sm text-muted text-center mt-1">Add to your editor</p>
    </a>

    <a
      href="/api-docs"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <div class="text-2xl mb-2">📡</div>
      <h3 class="font-semibold text-surface-content">API Docs</h3>
      <p class="text-sm text-muted text-center mt-1">Interactive reference</p>
    </a>
  </div>

  <h2 class="text-xl font-semibold text-surface-content mb-4">
    Popular Editors
  </h2>
  <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3 mb-8">
    {#each popular_editors as [name, slug]}
      <a
        href={`/docs/editors/${slug}`}
        class="flex flex-col items-center p-3 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
      >
        <img
          src={`/images/editor-icons/${slug}-128.png`}
          alt={name}
          class="w-10 h-10 mb-2"
        />
        <span class="text-sm text-surface-content">{name}</span>
      </a>
    {/each}
  </div>

  <details class="group">
    <summary
      class="flex items-center justify-between p-4 bg-surface border border-surface-200 rounded-lg cursor-pointer hover:border-surface-300 transition-colors select-none"
    >
      <span class="font-medium text-surface-content"
        >All {all_editors.length} supported editors</span
      >
      <svg
        class="w-5 h-5 text-muted group-open:rotate-180 transition-transform"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M19 9l-7 7-7-7"
        />
      </svg>
    </summary>
    <div
      class="grid grid-cols-4 sm:grid-cols-6 md:grid-cols-8 gap-2 mt-3 p-4 bg-surface border border-surface-200 rounded-lg select-none"
    >
      {#each all_editors as [name, slug]}
        <a
          href={`/docs/editors/${slug}`}
          class="flex flex-col items-center p-2 rounded hover:bg-surface-200 transition-colors"
        >
          <img
            src={`/images/editor-icons/${slug}-128.png`}
            alt={name}
            class="w-8 h-8 mb-1"
          />
          <span class="text-xs text-surface-content text-center leading-tight"
            >{name}</span
          >
        </a>
      {/each}
    </div>
  </details>

  <div class="mt-8 p-4 bg-surface border border-surface-200 rounded-lg">
    <p class="text-sm text-muted">
      Need help? Ask in
      <a
        href="https://hackclub.slack.com/archives/C07MQ845X1F"
        target="_blank"
        class="text-primary hover:underline">#hackatime-v2</a
      >
      on Slack or
      <a
        href="https://github.com/hackclub/hackatime/issues"
        target="_blank"
        class="text-primary hover:underline">open an issue</a
      >
      on GitHub.
    </p>
  </div>
</div>
