<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  let {
    popular_editors,
    all_editors,
  }: {
    popular_editors: [string, string][];
    all_editors: [string, string][];
  } = $props();
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

  <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 mb-8">
    <Link
      href="/my/wakatime_setup"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <svg class="w-6 h-6 mb-2 text-primary" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M14.615 1.595a.75.75 0 01.359.852L12.982 9.75h7.268a.75.75 0 01.548 1.262l-10.5 11.25a.75.75 0 01-1.272-.71l1.992-7.302H3.75a.75.75 0 01-.548-1.262l10.5-11.25a.75.75 0 01.913-.143z" clip-rule="evenodd" />
      </svg>
      <h3 class="font-semibold text-surface-content">Quick Start</h3>
      <p class="text-sm text-muted text-center mt-1">
        Set up in under a minute
      </p>
    </Link>

    <Link
      href="/docs/getting-started/installation"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <svg class="w-6 h-6 mb-2 text-primary" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M2.25 5.25a3 3 0 013-3h13.5a3 3 0 013 3V15a3 3 0 01-3 3h-3v.257c0 .597.237 1.17.659 1.591l.621.622H7.071l.621-.622A2.25 2.25 0 008.25 18.257V18h-3a3 3 0 01-3-3V5.25zm1.5 0v7.5a1.5 1.5 0 001.5 1.5h13.5a1.5 1.5 0 001.5-1.5v-7.5a1.5 1.5 0 00-1.5-1.5H5.25a1.5 1.5 0 00-1.5 1.5z" clip-rule="evenodd" />
      </svg>
      <h3 class="font-semibold text-surface-content">Installation</h3>
      <p class="text-sm text-muted text-center mt-1">Add to your editor</p>
    </Link>

    <Link
      href="/api-docs"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <svg class="w-6 h-6 mb-2 text-primary" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M14.447 3.027a.75.75 0 01.527.92l-4.5 16.5a.75.75 0 01-1.448-.394l4.5-16.5a.75.75 0 01.921-.526zM16.72 6.22a.75.75 0 011.06 0l5.25 5.25a.75.75 0 010 1.06l-5.25 5.25a.75.75 0 11-1.06-1.06L21.44 12l-4.72-4.72a.75.75 0 010-1.06zm-9.44 0a.75.75 0 010 1.06L2.56 12l4.72 4.72a.75.75 0 11-1.06 1.06L.97 12.53a.75.75 0 010-1.06l5.25-5.25a.75.75 0 011.06 0z" clip-rule="evenodd" />
      </svg>
      <h3 class="font-semibold text-surface-content">API Docs</h3>
      <p class="text-sm text-muted text-center mt-1">Interactive reference</p>
    </Link>

    <Link
      href="/docs/oauth/oauth-apps"
      class="flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
    >
      <svg class="w-6 h-6 mb-2 text-primary" fill="currentColor" viewBox="0 0 24 24">
        <path fill-rule="evenodd" d="M15.75 1.5a6.75 6.75 0 00-6.651 7.906c.067.39-.032.717-.221.906l-6.5 6.499a3 3 0 00-.878 2.121v2.818c0 .414.336.75.75.75H6a.75.75 0 00.75-.75v-1.5h1.5A.75.75 0 009 19.5V18h1.5a.75.75 0 00.53-.22l2.658-2.658c.19-.189.517-.288.906-.22A6.75 6.75 0 1015.75 1.5zm0 3a.75.75 0 000 1.5A2.25 2.25 0 0118 8.25a.75.75 0 001.5 0 3.75 3.75 0 00-3.75-3.75z" clip-rule="evenodd" />
      </svg>
      <h3 class="font-semibold text-surface-content">OAuth Apps</h3>
      <p class="text-sm text-muted text-center mt-1">Build integrations</p>
    </Link>
  </div>

  <h2 class="text-xl font-semibold text-surface-content mb-4">
    Popular Editors
  </h2>
  <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3 mb-8">
    {#each popular_editors as [name, slug]}
      <Link
        href={`/docs/editors/${slug}`}
        class="flex flex-col items-center p-3 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors"
      >
        <img
          src={`/images/editor-icons/${slug}-128.png`}
          alt={name}
          class="w-10 h-10 mb-2"
        />
        <span class="text-sm text-surface-content">{name}</span>
      </Link>
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
        <Link
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
        </Link>
      {/each}
    </div>
  </details>

  <div class="mt-8 p-4 bg-surface border border-surface-200 rounded-lg">
    <p class="text-sm text-muted">
      Need help? Ask in
      <Link
        href="https://hackclub.slack.com/archives/C07MQ845X1F"
        target="_blank"
        class="text-primary hover:underline">#hackatime-v2</Link
      >
      on Slack or
      <Link
        href="https://github.com/hackclub/hackatime/issues"
        target="_blank"
        class="text-primary hover:underline">open an issue</Link
      >
      on GitHub.
    </p>
  </div>
</div>
