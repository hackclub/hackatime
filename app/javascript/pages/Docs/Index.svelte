<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import {
    Icon,
    Bolt,
    ComputerDesktop,
    CodeBracket,
    Key,
    ChevronDown,
    type IconSource,
  } from "svelte-hero-icons";

  let {
    popular_editors,
    all_editors,
  }: {
    popular_editors: [string, string][];
    all_editors: [string, string][];
  } = $props();

  const QUICK_LINKS: {
    href: string;
    title: string;
    desc: string;
    icon: IconSource;
    external?: boolean;
  }[] = [
    {
      href: "/setup",
      title: "Quick Start",
      desc: "Set up in under a minute",
      icon: Bolt,
    },
    {
      href: "/docs/getting-started/installation",
      title: "Installation",
      desc: "Add to your editor",
      icon: ComputerDesktop,
    },
    {
      href: "/api-docs",
      title: "API Docs",
      desc: "Interactive reference",
      external: true,
      icon: CodeBracket,
    },
    {
      href: "/docs/oauth/oauth-apps",
      title: "OAuth Apps",
      desc: "Build integrations",
      icon: Key,
    },
  ];

  const quickCls =
    "flex flex-col items-center justify-center p-6 bg-surface border border-surface-200 rounded-lg hover:border-primary transition-colors";
</script>

<svelte:head>
  <title>Documentation - Hackatime</title>
  <meta
    name="description"
    content="Complete documentation for Hackatime - learn how to track your coding time and use our API."
  />
</svelte:head>

<div>
  <div class="mb-6 sm:mb-8">
    <h1
      class="text-2xl sm:text-3xl font-bold text-surface-content mb-1 sm:mb-2"
    >
      Documentation
    </h1>
    <p class="text-sm sm:text-base text-muted">
      Free, open-source time tracking for Hack Club. Like WakaTime, but free.
    </p>
  </div>

  <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-4 mb-8">
    {#each QUICK_LINKS as { href, title, desc, icon, external }}
      {#snippet body()}
        <Icon src={icon} solid size="24" class="mb-2 text-primary" />
        <h3 class="font-semibold text-surface-content">{title}</h3>
        <p class="text-sm text-muted text-center mt-1">{desc}</p>
      {/snippet}
      {#if external}
        <a {href} class={quickCls}>{@render body()}</a>
      {:else}
        <Link {href} class={quickCls}>{@render body()}</Link>
      {/if}
    {/each}
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
      <Icon
        src={ChevronDown}
        size="20"
        class="text-muted group-open:rotate-180 transition-transform"
      />
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
      <a
        href="https://hackclub.slack.com/archives/C07MQ845X1F"
        target="_blank"
        class="text-primary hover:underline">#hackatime-help</a
      >
      on Slack or
      <a
        href="https://github.com/hackclub/hackatime/issues"
        target="_blank"
        class="text-primary hover:underline">open an issue</a
      >
      on GitHub.
    </p>
    <Link
      href="/docs/troubleshooting/hackatime-stuck-initialised"
      class="mt-2 inline-block text-sm text-primary hover:underline"
    >
      Hackatime stuck initialised →
    </Link>
  </div>
</div>
