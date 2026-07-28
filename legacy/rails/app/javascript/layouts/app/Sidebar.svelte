<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import UserSummary from "./UserSummary.svelte";
  import type { LayoutNav, NavLink } from "../../types";
  import { sessions } from "../../api";
  import Menu from "hcicons-svelte/menu";

  let {
    nav,
    navOpen,
    onToggle,
    onClose,
    onLogout,
  }: {
    nav: LayoutNav;
    navOpen: boolean;
    onToggle: () => void;
    onClose: () => void;
    onLogout: () => void;
  } = $props();

  const loginPath = sessions.slackNew.path();
  const isBrowser = typeof window !== "undefined";

  const handleNavLinkClick = () => {
    if (isBrowser && window.innerWidth <= 1024) onClose();
  };

  const linkCls = (active?: boolean, tool = "") =>
    `group flex min-h-10 w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${active ? "nav-link-active bg-primary text-on-primary font-bold" : "text-surface-content hover:bg-darkless hover:text-primary hover:shadow-[0_1px_0_rgba(255,255,255,0.06)]"}${tool ? ` ${tool}` : ""}`;

  const cacheFor = (link: NavLink): string | [string, string] =>
    link.label === "Docs" || link.label === "Extensions"
      ? "10m"
      : ["0s", "30s"];

  const adminSections = $derived([
    { links: nav.dev_links, tool: "dev-tool" },
    { links: nav.admin_links, tool: "admin-tool" },
    { links: nav.viewer_links, tool: "viewer-tool" },
    { links: nav.superadmin_links, tool: "superadmin-tool" },
    { links: nav.ultraadmin_links || [], tool: "ultraadmin-tool" },
  ]);
  const hasAdminLinks = $derived(adminSections.some((s) => s.links.length > 0));
</script>

{#snippet badge(link: NavLink)}
  {#if link.badge}
    <span
      class={`ml-2 rounded-full px-1.5 py-0.5 text-xs font-medium tabular-nums ${link.active ? "bg-on-primary/20 text-on-primary" : "bg-primary text-on-primary"}`}
      >{link.badge}</span
    >
  {/if}
{/snippet}

{#snippet item(link: NavLink, tool = "")}
  {#if link.action === "logout"}
    <Button
      type="button"
      unstyled
      onclick={onLogout}
      class={`${linkCls(false)} cursor-pointer w-full text-left`}>Logout</Button
    >
  {:else if link.inertia}
    <Link
      href={link.href || "#"}
      prefetch
      cacheFor={cacheFor(link)}
      onclick={handleNavLinkClick}
      class={linkCls(link.active, tool)}>{link.label}{@render badge(link)}</Link
    >
  {:else}
    <a
      href={link.href || "#"}
      onclick={handleNavLinkClick}
      class={linkCls(link.active, tool)}
    >
      {link.label}{@render badge(link)}
    </a>
  {/if}
{/snippet}

<Button
  type="button"
  unstyled
  class="mobile-nav-button"
  aria-label="Toggle navigation menu"
  aria-expanded={navOpen}
  onclick={onToggle}
>
  <Menu size={24} aria-hidden="true" />
</Button>
<Button
  type="button"
  unstyled
  class={`nav-overlay ${navOpen ? "open" : ""}`}
  onclick={onClose}
  aria-label="Close navigation menu"
></Button>

<aside
  class="flex min-h-screen w-52 flex-col overflow-y-auto rounded-r-2xl bg-dark px-3 py-4 text-surface-content shadow-[4px_0_24px_rgba(0,0,0,0.16),inset_-1px_0_0_rgba(255,255,255,0.06)] lg:block"
  data-nav-target="nav"
  class:open={navOpen}
  style="scrollbar-width: none; -ms-overflow-style: none;"
>
  <div class="space-y-4">
    {#if nav.user_present && nav.current_user}
      <div
        class="flex flex-col items-center gap-2 rounded-xl px-2 pb-3 shadow-[0_1px_0_rgba(255,255,255,0.08)]"
      >
        <UserSummary user={nav.current_user} />
      </div>
    {:else if !nav.user_present}
      <div>
        <a
          href={loginPath}
          class="block px-4 py-2 rounded-md transition text-on-primary font-semibold bg-primary hover:bg-secondary text-center"
          >Login</a
        >
      </div>
    {/if}

    <nav class="space-y-1">
      {#each nav.links as link}{@render item(link)}{/each}

      {#if hasAdminLinks}
        <div
          class="mt-2 space-y-1 pt-2 shadow-[0_-1px_0_rgba(255,255,255,0.08)]"
        >
          {#each adminSections as { links, tool }}
            {#each links as link}{@render item(link, tool)}{/each}
          {/each}
        </div>
      {/if}
    </nav>
  </div>
</aside>
