<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../components/Button.svelte";
  import type { Snippet } from "svelte";
  import { onMount, onDestroy } from "svelte";

  type DocsNavLink = { label: string; href: string };
  type DocsNavSection = { title: string; links: DocsNavLink[] };
  type DocsNav = {
    current_path: string;
    home_url: string;
    api_docs_url: string;
    github_url: string;
    slack_url: string;
    sections: DocsNavSection[];
    popular_editors: [string, string][];
    all_editors: [string, string][];
  };

  let { docs_nav, children }: { docs_nav: DocsNav; children?: Snippet } =
    $props();

  const isBrowser =
    typeof window !== "undefined" && typeof document !== "undefined";

  let navOpen = $state(false);

  const toggleNav = () => (navOpen = !navOpen);
  const closeNav = () => (navOpen = false);

  const isActive = (href: string) => {
    if (!href) return false;
    const currentPath = docs_nav.current_path || "/docs";
    if (href === docs_nav.home_url) {
      return currentPath === docs_nav.home_url || currentPath === "/docs";
    }
    return currentPath === href || currentPath.startsWith(`${href}/`);
  };

  const handleNavLinkClick = () => {
    if (isBrowser && window.innerWidth <= 1024) closeNav();
  };

  const handleResize = () => {
    if (isBrowser && window.innerWidth > 1024) closeNav();
  };

  const handleKeydown = (e: KeyboardEvent) => {
    if (e.key === "Escape") closeNav();
  };

  $effect(() => {
    if (isBrowser) document.body.classList.toggle("overflow-hidden", navOpen);
  });

  onMount(() => {
    if (!isBrowser) return;
    handleResize();
    window.addEventListener("resize", handleResize);
    document.addEventListener("keydown", handleKeydown);
  });

  onDestroy(() => {
    if (isBrowser) {
      window.removeEventListener("resize", handleResize);
      document.removeEventListener("keydown", handleKeydown);
    }
  });

  const navLinkClass = (active?: boolean) =>
    `block px-3 py-2 rounded-md text-sm transition-colors ${
      active
        ? "bg-primary text-on-primary font-bold"
        : "text-surface-content hover:bg-darkless hover:text-primary"
    }`;

  const sectionTitleClass =
    "px-3 pt-3 pb-1 text-[11px] uppercase tracking-wider text-secondary/80 font-semibold";

  const resourceLinkClass =
    "flex items-center justify-between px-3 py-2 rounded-md text-sm transition-colors text-surface-content hover:bg-darkless hover:text-primary";
</script>

<Button
  type="button"
  unstyled
  class="mobile-nav-button"
  aria-label="Toggle docs navigation"
  aria-expanded={navOpen}
  onclick={toggleNav}
>
  <svg
    xmlns="http://www.w3.org/2000/svg"
    fill="none"
    viewBox="0 0 24 24"
    stroke="currentColor"
    aria-hidden="true"
  >
    <path
      stroke-linecap="round"
      stroke-linejoin="round"
      stroke-width="2"
      d="M4 6h16M4 12h16M4 18h16"
    />
  </svg>
</Button>

<Button
  type="button"
  unstyled
  class={`nav-overlay ${navOpen ? "open" : ""}`}
  onclick={closeNav}
  aria-label="Close docs navigation"
></Button>

<aside
  class="flex flex-col min-h-screen w-60 bg-dark text-surface-content px-3 py-4 rounded-r-lg overflow-y-auto lg:block"
  data-nav-target="nav"
  class:open={navOpen}
  style="scrollbar-width: none; -ms-overflow-style: none;"
>
  <!-- Branding / header -->
  <div class="px-3 pb-3 mb-2 border-b border-darkless">
    <Link
      href={docs_nav.home_url}
      onclick={handleNavLinkClick}
      class="flex items-center gap-2 group"
    >
      <div class="flex flex-col leading-tight">
        <span class="text-sm font-bold text-surface-content">Hackatime</span>
        <span class="text-[11px] uppercase tracking-wider text-secondary"
          >Documentation</span
        >
      </div>
    </Link>
  </div>

  <nav class="space-y-1">
    <!-- Overview -->
    <Link
      href={docs_nav.home_url}
      prefetch
      cacheFor="10m"
      onclick={handleNavLinkClick}
      class={navLinkClass(isActive(docs_nav.home_url))}
    >
      Overview
    </Link>

    <!-- Sections -->
    {#each docs_nav.sections as section}
      <div class={sectionTitleClass}>{section.title}</div>
      {#each section.links as link}
        <Link
          href={link.href}
          prefetch
          cacheFor="10m"
          onclick={handleNavLinkClick}
          class={navLinkClass(isActive(link.href))}
        >
          {link.label}
        </Link>
      {/each}
    {/each}

    <!-- Editors -->
    <div class={sectionTitleClass}>Editors</div>
    {#each docs_nav.popular_editors.slice(0, 8) as [name, slug]}
      {@const active = isActive(`/docs/editors/${slug}`)}
      <Link
        href={`/docs/editors/${slug}`}
        prefetch
        cacheFor="10m"
        onclick={handleNavLinkClick}
        class={`flex items-center gap-2 px-3 py-1.5 rounded-md text-sm transition-colors ${
          active
            ? "bg-primary text-on-primary font-bold"
            : "text-surface-content hover:bg-darkless hover:text-primary"
        }`}
      >
        <img
          src={`/images/editor-icons/${slug}-128.png`}
          alt=""
          class="w-4 h-4 shrink-0"
          loading="lazy"
        />
        <span class="truncate">{name}</span>
      </Link>
    {/each}
    <Link
      href={docs_nav.home_url}
      onclick={handleNavLinkClick}
      class={navLinkClass(false) + " text-secondary"}
    >
      All {docs_nav.all_editors.length} editors →
    </Link>

    <!-- Resources -->
    <div class={sectionTitleClass}>Resources</div>
    <a
      href={docs_nav.api_docs_url}
      onclick={handleNavLinkClick}
      class={resourceLinkClass}
    >
      API Reference
      <svg
        class="w-3 h-3 text-muted"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M14 5l7 7m0 0l-7 7m7-7H3"
        />
      </svg>
    </a>
    <a
      href={docs_nav.github_url}
      target="_blank"
      rel="noopener"
      onclick={handleNavLinkClick}
      class={resourceLinkClass}
    >
      GitHub
      <svg
        class="w-3 h-3 text-muted"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
        />
      </svg>
    </a>
    <a
      href={docs_nav.slack_url}
      target="_blank"
      rel="noopener"
      onclick={handleNavLinkClick}
      class={resourceLinkClass}
    >
      #hackatime-help
      <svg
        class="w-3 h-3 text-muted"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"
        />
      </svg>
    </a>

    <!-- Back to app -->
    <div class="pt-3 mt-3 border-t border-darkless">
      <a
        href="/"
        onclick={handleNavLinkClick}
        class="flex items-center gap-2 px-3 py-2 rounded-md text-sm transition-colors text-secondary hover:bg-darkless hover:text-primary"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="w-4 h-4"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            stroke-width="2"
            d="M10 19l-7-7m0 0l7-7m-7 7h18"
          />
        </svg>
        Back to Hackatime
      </a>
    </div>
  </nav>
</aside>

<main
  class="flex-1 min-h-screen transition-all duration-300 ease-in-out lg:ml-72"
>
  <div class="w-full max-w-5xl mx-auto p-4 pt-16 lg:pt-8 md:p-8">
    {@render children?.()}
  </div>
</main>

<style>
  :global(#app) {
    display: flex;
    flex: 1 1 auto;
    min-height: 100vh;
    width: 100%;
  }
</style>
