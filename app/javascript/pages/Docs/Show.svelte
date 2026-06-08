<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import GithubFill from "hcicons-svelte/github-fill";

  let {
    title,
    rendered_content,
    breadcrumbs,
    edit_url,
    meta,
  }: {
    doc_path: string;
    title: string;
    rendered_content: string;
    breadcrumbs: { name: string; href: string | null; is_link: boolean }[];
    edit_url: string;
    meta: { description: string; keywords: string };
  } = $props();
</script>

<svelte:head>
  <title>{title} - Hackatime Documentation</title>
  <meta name="description" content={meta.description} />
  <meta name="keywords" content={meta.keywords} />
  <meta property="og:title" content={`${title} - Hackatime Documentation`} />
  <meta property="og:description" content={meta.description} />
  <meta property="og:type" content="article" />
</svelte:head>

<div class="min-h-screen text-surface-content">
  <div class="w-full max-w-5xl mx-auto px-4 py-6 sm:px-6 sm:py-8 lg:px-8">
    <nav class="mb-8">
      {#each breadcrumbs as crumb, i}
        {#if i === breadcrumbs.length - 1}
          <span class="text-primary">{crumb.name}</span>
        {:else}
          {#if crumb.is_link && crumb.href}
            <Link href={crumb.href} class="text-secondary hover:text-primary"
              >{crumb.name}</Link
            >
          {:else}
            <span class="text-secondary">{crumb.name}</span>
          {/if}
          <span class="text-secondary mx-2">/</span>
        {/if}
      {/each}
    </nav>

    <div class="docs-prose">{@html rendered_content}</div>

    <div
      class="flex items-center justify-center gap-2 py-6 text-sm text-secondary/70"
    >
      <span>Found an issue with this page?</span>
      <a
        href={edit_url}
        target="_blank"
        class="inline-flex items-center gap-1 text-primary hover:text-red transition-colors font-medium"
      >
        <GithubFill size={16} />
        Edit on GitHub
      </a>
    </div>
  </div>
</div>
