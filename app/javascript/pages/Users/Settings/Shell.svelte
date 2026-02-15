<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";
  import { onMount } from "svelte";
  import { buildSections, sectionFromHash } from "./types";
  import type { SectionPaths, SettingsCommonProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    errors,
    admin_tools,
    children,
  }: SettingsCommonProps & { children?: Snippet } = $props();

  const sections = $derived(buildSections(section_paths, admin_tools.visible));
  const knownSectionIds = $derived(new Set(sections.map((section) => section.id)));

  const sectionButtonClass = (sectionId: keyof SectionPaths) =>
    `block w-full px-3 py-3 text-left transition-colors ${
      active_section === sectionId
        ? "bg-surface-100 text-surface-content"
        : "bg-surface text-muted hover:bg-surface-100 hover:text-surface-content"
    }`;

  onMount(() => {
    const syncSectionFromHash = () => {
      const section = sectionFromHash(window.location.hash);
      if (!section || !knownSectionIds.has(section)) return;
      if (section === active_section || !section_paths[section]) return;

      window.location.replace(`${section_paths[section]}${window.location.hash}`);
    };

    syncSectionFromHash();
    window.addEventListener("hashchange", syncSectionFromHash);
    return () => window.removeEventListener("hashchange", syncSectionFromHash);
  });
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-7xl">
  <header class="mb-8">
    <h1 class="text-3xl font-bold text-surface-content">{heading}</h1>
    <p class="mt-2 text-sm text-muted">{subheading}</p>
  </header>

  {#if errors.full_messages.length > 0}
    <div class="mb-6 rounded-lg border border-danger/40 bg-danger/10 px-4 py-3 text-sm text-red-200">
      <p class="font-semibold">Some changes could not be saved:</p>
      <ul class="mt-2 list-disc pl-5">
        {#each errors.full_messages as message}
          <li>{message}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <div class="grid grid-cols-1 gap-6 lg:grid-cols-[260px_minmax(0,1fr)]">
    <aside class="h-max lg:sticky lg:top-8">
      <div class="overflow-hidden rounded-xl border border-[#4A3438] bg-surface divide-y divide-[#4A3438]">
        {#each sections as section}
          <Link href={section.path} class={sectionButtonClass(section.id)}>
            <p class="text-sm font-semibold">{section.label}</p>
            <p class="mt-1 text-xs opacity-80">{section.blurb}</p>
          </Link>
        {/each}
      </div>
    </aside>

    <section class="rounded-xl border border-surface-200 bg-surface p-5 md:p-6">
      {@render children?.()}
    </section>
  </div>
</div>
