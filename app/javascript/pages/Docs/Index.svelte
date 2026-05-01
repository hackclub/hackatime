<script module lang="ts">
  import DocsLayout from "../../layouts/DocsLayout.svelte";
  export const layout = DocsLayout;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  let {
    popular_editors,
    all_editors,
  }: {
    popular_editors: [string, string][];
    all_editors: [string, string][];
  } = $props();

  const quickLinkClass =
    "group flex items-start gap-3 rounded-lg border border-surface-200 bg-surface p-4 transition-colors hover:border-primary";
  const editorCardClass =
    "flex flex-col items-center rounded-lg border border-surface-200 bg-surface p-3 transition-colors hover:border-primary";
  const compactEditorCardClass =
    "flex flex-col items-center rounded p-2 transition-colors hover:bg-surface-200";
</script>

<svelte:head>
  <title>Documentation - Hackatime</title>
  <meta
    name="description"
    content="Complete documentation for Hackatime - learn how to track your coding time and use our API."
  />
</svelte:head>

<!-- Hero -->
<header class="mb-10">
  <h1 class="text-3xl font-bold text-surface-content mb-3">Docs</h1>
  <p class="text-lg text-muted max-w-2xl">
    Learn how to use Hackatime, the open-source time tracking tool from Hack
    Club.
  </p>
</header>

<!-- Quick path cards -->
<section class="grid grid-cols-1 sm:grid-cols-2 gap-3 mb-12">
  <Link href="/my/wakatime_setup" class={quickLinkClass}>
    <div>
      <h3 class="font-semibold text-surface-content">Quick Start</h3>
      <p class="text-sm text-muted mt-0.5">
        Personalised setup for your editor in under a minute.
      </p>
    </div>
  </Link>

  <Link href="/docs/getting-started/installation" class={quickLinkClass}>
    <div>
      <h3 class="font-semibold text-surface-content">Installation</h3>
      <p class="text-sm text-muted mt-0.5">
        Step-by-step instructions for every supported editor.
      </p>
    </div>
  </Link>

  <a href="/api-docs" class={quickLinkClass}>
    <div>
      <h3 class="font-semibold text-surface-content">API Reference</h3>
      <p class="text-sm text-muted mt-0.5">
        Interactive Swagger reference for the public API.
      </p>
    </div>
  </a>

  <Link href="/docs/oauth/oauth-apps" class={quickLinkClass}>
    <div>
      <h3 class="font-semibold text-surface-content">OAuth Apps</h3>
      <p class="text-sm text-muted mt-0.5">
        Build integrations on top of Hackatime's OAuth provider.
      </p>
    </div>
  </Link>
</section>

<!-- Popular editors -->
<section class="mb-10">
  <div class="flex items-baseline justify-between mb-4">
    <h2 class="text-xl font-semibold text-surface-content">Popular editors</h2>
    <div class="text-sm text-muted tabular-nums">
      {popular_editors.length} of {all_editors.length}
    </div>
  </div>
  <div class="grid grid-cols-3 sm:grid-cols-4 md:grid-cols-6 gap-3">
    {#each popular_editors as [name, slug]}
      <Link href={`/docs/editors/${slug}`} class={editorCardClass}>
        <img
          src={`/images/editor-icons/${slug}-128.png`}
          alt={name}
          class="mb-2 size-10"
          loading="lazy"
        />
        <div class="text-center text-sm text-surface-content">{name}</div>
      </Link>
    {/each}
  </div>
</section>

<!-- All editors -->
<details class="group mb-10">
  <summary
    class="flex items-center justify-between p-4 bg-surface border border-surface-200 rounded-lg cursor-pointer hover:border-surface-300 transition-colors select-none"
  >
    <div class="font-medium text-surface-content tabular-nums">
      Browse all {all_editors.length} supported editors
    </div>
    <svg
      class="size-5 text-muted transition-transform group-open:rotate-180"
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
      <Link href={`/docs/editors/${slug}`} class={compactEditorCardClass}>
        <img
          src={`/images/editor-icons/${slug}-128.png`}
          alt={name}
          class="mb-1 size-8"
          loading="lazy"
        />
        <div class="text-center text-xs text-surface-content">{name}</div>
      </Link>
    {/each}
  </div>
</details>

<!-- Help footer -->
<aside
  class="flex flex-col gap-2 rounded-lg border border-surface-200 bg-surface p-4 sm:flex-row sm:items-center sm:justify-between"
>
  <p class="text-sm text-muted">Stuck? We're around to help.</p>
  <div class="flex flex-wrap items-center gap-x-4 gap-y-1 text-sm">
    <a
      href="https://hackclub.slack.com/archives/C07MQ845X1F"
      target="_blank"
      rel="noopener"
      class="text-primary hover:underline">#hackatime-help on Slack</a
    >
    <a
      href="https://github.com/hackclub/hackatime/issues"
      target="_blank"
      rel="noopener"
      class="text-primary hover:underline">Open a GitHub issue</a
    >
  </div>
</aside>
