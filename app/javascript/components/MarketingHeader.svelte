<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import { staticPages } from "../api";

  type NavLink = {
    href: string;
    label: string;
    external?: boolean;
  };

  let {
    navLinks,
    ctaLabel,
  }: {
    navLinks: NavLink[];
    ctaLabel: string;
  } = $props();
</script>

<header
  class="fixed top-0 w-full bg-darker/95 backdrop-blur-sm z-50 border-b border-surface-200/60"
>
  <div
    class="max-w-[1100px] mx-auto px-6 py-4 flex justify-between items-center"
  >
    <Link href={staticPages.index.path()} class="flex items-center gap-3">
      <img
        src="/images/new-icon-rounded.png"
        class="w-10 h-10 rounded-lg"
        alt="Hackatime"
      />
      <span class="font-bold text-2xl tracking-tight">Hackatime</span>
    </Link>
    <nav
      class="hidden md:flex gap-8 items-center text-sm font-medium text-secondary"
    >
      {#each navLinks as { href, label, external }}
        <a
          {href}
          target={external ? "_blank" : undefined}
          class="hover:text-surface-content transition-colors">{label}</a
        >
      {/each}
      <Link
        href={staticPages.signin.path()}
        class="px-4 py-2 bg-primary text-on-primary rounded-md font-semibold hover:opacity-90 transition-colors"
      >
        {ctaLabel}
      </Link>
    </nav>
  </div>
</header>
