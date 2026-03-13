<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";
  import { onMount } from "svelte";
  import SubsectionNav from "./components/SubsectionNav.svelte";
  import { buildSections, buildSubsections, sectionFromHash } from "./types";
  import type { SectionPaths, SettingsCommonProps } from "./types";

  let {
    active_section,
    section_paths,
    page_title,
    heading,
    subheading,
    errors,
    children,
    hidden_subsections,
  }: SettingsCommonProps & {
    children?: Snippet;
    hidden_subsections?: Set<string>;
  } = $props();

  const sections = $derived(buildSections(section_paths));
  const subsections = $derived(
    buildSubsections(active_section, hidden_subsections),
  );
  const knownSectionIds = $derived(
    new Set(sections.map((section) => section.id)),
  );

  const sectionButtonClass = (sectionId: keyof SectionPaths) =>
    `group block w-full rounded-xl border px-3 py-3 text-left transition-colors ${
      active_section === sectionId
        ? "border-surface-300 bg-surface-100 text-surface-content shadow-[0_1px_0_rgba(255,255,255,0.02)]"
        : "border-transparent bg-transparent text-muted hover:border-surface-200 hover:bg-surface-100/60 hover:text-surface-content"
    }`;

  onMount(() => {
    const syncSectionFromHash = () => {
      const section = sectionFromHash(window.location.hash);
      if (!section || !knownSectionIds.has(section)) return;
      if (section === active_section || !section_paths[section]) return;

      window.location.replace(
        `${section_paths[section]}${window.location.hash}`,
      );
    };

    syncSectionFromHash();
    window.addEventListener("hashchange", syncSectionFromHash);
    return () => window.removeEventListener("hashchange", syncSectionFromHash);
  });
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div data-settings-shell class="mx-auto max-w-7xl">
  <header class="mb-8">
    <h1 class="text-3xl font-bold tracking-tight text-surface-content">
      {heading}
    </h1>
    <p class="mt-2 max-w-3xl text-sm leading-6 text-muted">{subheading}</p>
  </header>

  {#if errors.full_messages.length > 0}
    <div
      class="mb-6 rounded-lg border border-danger/40 bg-danger/10 px-4 py-3 text-sm text-red"
    >
      <p class="font-semibold">Some changes could not be saved:</p>
      <ul class="mt-2 list-disc pl-5">
        {#each errors.full_messages as message}
          <li>{message}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <nav
    data-settings-mobile-nav
    class="-mx-5 mb-6 overflow-x-auto px-5 lg:hidden"
  >
    <div class="flex min-w-full gap-2 pb-1">
      {#each sections as section}
        <Link
          href={section.path}
          class={`inline-flex shrink-0 items-center rounded-full border px-3 py-2 text-sm font-medium transition-colors ${
            active_section === section.id
              ? "border-surface-300 bg-surface-100 text-surface-content"
              : "border-surface-200 bg-surface/70 text-muted hover:border-surface-300 hover:text-surface-content"
          }`}
        >
          {section.label}
        </Link>
      {/each}
    </div>
  </nav>

  <div
    class="grid grid-cols-1 gap-6 lg:grid-cols-[280px_minmax(0,1fr)] lg:gap-8"
  >
    <aside class="hidden h-max lg:sticky lg:top-8 lg:block">
      <div
        data-settings-sidebar
        class="rounded-2xl border border-surface-200 bg-surface/90 p-2 shadow-[0_1px_0_rgba(255,255,255,0.02)]"
      >
        {#each sections as section}
          <Link href={section.path} class={sectionButtonClass(section.id)}>
            <p class="text-sm font-semibold">{section.label}</p>
            <p class="mt-1 text-xs leading-5 opacity-80">{section.blurb}</p>
          </Link>
        {/each}
      </div>
    </aside>

    <div data-settings-content class="min-w-0 space-y-5">
      <SubsectionNav items={subsections} />
      <div class="space-y-5">
        {@render children?.()}
      </div>
    </div>
  </div>
</div>
