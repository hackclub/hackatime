<script lang="ts">
  import { Link, router, usePoll } from "@inertiajs/svelte";
  import Button from "../components/Button.svelte";
  import CountryFlag from "../components/CountryFlag.svelte";
  import CurrentlyHackingPanel from "../components/CurrentlyHackingPanel.svelte";
  import Modal from "../components/Modal.svelte";
  import type { Snippet } from "svelte";
  import { onMount, onDestroy } from "svelte";
  import plur from "plur";
  import { streakTheme, streakLabel } from "../utils";
  import type {
    AdminLevel,
    LayoutNav,
    LayoutProps,
    NavCurrentUser,
    NavLink,
  } from "../types";

  let { layout, children }: { layout: LayoutProps; children?: Snippet } =
    $props();

  const isBrowser =
    typeof window !== "undefined" && typeof document !== "undefined";

  let navOpen = $state(false);
  let logoutOpen = $state(false);
  let flashVisible = $state(false);
  let flashHiding = $state(false);
  let visibleFlash = $state<LayoutNav["flash"]>([]);
  let activeFlashSignature = "";
  let flashHideTimeoutId: ReturnType<typeof setTimeout> | undefined;
  let flashRemoveTimeoutId: ReturnType<typeof setTimeout> | undefined;
  const flashHideDelay = 6000;
  const flashExitDuration = 250;
  const currentlyHackingPollInterval = () =>
    layout.currently_hacking?.interval || 30000;

  const toggleNav = () => (navOpen = !navOpen);
  const closeNav = () => (navOpen = false);
  const openLogout = () => {
    logoutOpen = true;
  };
  const closeLogout = () => (logoutOpen = false);

  usePoll(currentlyHackingPollInterval(), {
    only: ["currently_hacking"],
  });

  const handleNavLinkClick = () => {
    if (isBrowser && window.innerWidth <= 1024) closeNav();
  };

  const handleResize = () => {
    if (isBrowser && window.innerWidth > 1024) closeNav();
  };

  const handleKeydown = (e: KeyboardEvent) => {
    if (e.key === "Escape") {
      closeNav();
      closeLogout();
    }
  };

  const latinPhrases = [
    "carpe diem",
    "nemo sine vitio est",
    "docendo discimus",
    "per aspera ad astra",
    "ex nihilo nihil",
    "aut viam inveniam aut faciam",
    "semper ad mellora",
    "soli fortes, una fortiores",
    "nulla tenaci invia est via",
    "nihil boni sine labore",
  ];

  const activeUsersGraphTitle = (hourIndex: number, users: number) => {
    const hoursAgo = hourIndex + 1;
    const phrase = latinPhrases[(hoursAgo + users) % latinPhrases.length];
    return `${hoursAgo} ${plur("hour", hoursAgo)} ago, ${users} ${plur("person", users)} logged time. '${phrase}.'`;
  };

  const footerStatsText = () =>
    `${layout.footer.heartbeat_recent_count} ${plur("heartbeat", layout.footer.heartbeat_recent_count)} (${layout.footer.heartbeat_recent_imported_count} imported) in the past 24 hours. (DB: ${layout.footer.query_count} ${plur("query", layout.footer.query_count)}, ${layout.footer.query_cache_count} cached) (CACHE: ${layout.footer.cache_hits} hits, ${layout.footer.cache_misses} misses) (${layout.footer.requests_per_second})`;

  const adminLevelMeta: Partial<
    Record<AdminLevel, { label: string; class: string }>
  > = {
    ultraadmin: {
      label: "Ultraadmin",
      class: "text-purple-400 ultraadmin-tool",
    },
    superadmin: { label: "Superadmin", class: "text-red superadmin-tool" },
    admin: { label: "Admin", class: "text-yellow admin-tool" },
    viewer: { label: "Viewer", class: "text-blue viewer-tool" },
  };

  const adminMetaFor = (adminLevel?: AdminLevel | null) =>
    adminLevel ? adminLevelMeta[adminLevel] : null;

  $effect(() => {
    if (isBrowser) document.body.classList.toggle("overflow-hidden", navOpen);
  });

  $effect(() => {
    if (!layout.nav.flash.length) {
      return;
    }

    const nextFlashSignature = flashSignature(layout.nav.flash);
    if (nextFlashSignature === activeFlashSignature) {
      return;
    }

    activeFlashSignature = nextFlashSignature;
    if (flashHideTimeoutId) clearTimeout(flashHideTimeoutId);
    if (flashRemoveTimeoutId) clearTimeout(flashRemoveTimeoutId);

    visibleFlash = layout.nav.flash;
    flashVisible = true;
    flashHiding = false;
    router.replaceProp("layout.nav.flash", []);
    flashHideTimeoutId = setTimeout(() => {
      flashHiding = true;
      flashRemoveTimeoutId = setTimeout(() => {
        flashVisible = false;
        flashHiding = false;
        visibleFlash = [];
        activeFlashSignature = "";
      }, flashExitDuration);
    }, flashHideDelay);
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
    if (flashHideTimeoutId) clearTimeout(flashHideTimeoutId);
    if (flashRemoveTimeoutId) clearTimeout(flashRemoveTimeoutId);
  });

  const navLinkClass = (active?: boolean) =>
    `group flex min-h-10 w-full items-center justify-between rounded-lg px-3 py-2 text-sm transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${active ? "bg-primary text-on-primary font-bold shadow-[0_8px_20px_rgba(0,0,0,0.18),inset_0_1px_0_rgba(255,255,255,0.18)]" : "text-surface-content hover:bg-darkless hover:text-primary hover:shadow-[0_1px_0_rgba(255,255,255,0.06)]"}`;

  const navLinkWithToolClass = (link: NavLink, toolClass = "") =>
    `${navLinkClass(link.active)}${toolClass ? ` ${toolClass}` : ""}`;

  const isLongCachedLink = (link: NavLink) =>
    link.label === "Docs" || link.label === "Extensions";

  const linkCacheFor = (link: NavLink): string | [string, string] =>
    isLongCachedLink(link) ? "10m" : ["0s", "30s"];

  const flashSignature = (flash: LayoutNav["flash"]) =>
    JSON.stringify(
      flash.map(({ message, class_name }) => [message, class_name]),
    );

  const adminLinkSections = () => [
    { links: layout.nav.dev_links, toolClass: "dev-tool" },
    { links: layout.nav.admin_links, toolClass: "admin-tool" },
    { links: layout.nav.viewer_links, toolClass: "viewer-tool" },
    { links: layout.nav.superadmin_links, toolClass: "superadmin-tool" },
    { links: layout.nav.ultraadmin_links || [], toolClass: "ultraadmin-tool" },
  ];

  const hasAdminLinks = () =>
    adminLinkSections().some(({ links }) => links.length > 0);
</script>

{#snippet navBadge(link: NavLink)}
  {#if link.badge}
    <span
      class={`ml-2 rounded-full px-1.5 py-0.5 text-xs font-medium tabular-nums ${link.active ? "bg-on-primary/20 text-on-primary" : "bg-primary text-on-primary"}`}
    >
      {link.badge}
    </span>
  {/if}
{/snippet}

{#snippet navItem(link: NavLink, toolClass = "")}
  {#if link.action === "logout"}
    <Button
      type="button"
      unstyled
      onclick={openLogout}
      class={`${navLinkClass(false)} cursor-pointer w-full text-left`}
      >Logout</Button
    >
  {:else if link.inertia}
    <Link
      href={link.href || "#"}
      prefetch
      cacheFor={linkCacheFor(link)}
      onclick={handleNavLinkClick}
      class={navLinkWithToolClass(link, toolClass)}
    >
      {link.label}
      {@render navBadge(link)}
    </Link>
  {:else}
    <a
      href={link.href || "#"}
      onclick={handleNavLinkClick}
      class={navLinkWithToolClass(link, toolClass)}
    >
      {link.label}
      {@render navBadge(link)}
    </a>
  {/if}
{/snippet}

{#snippet userAvatar(user: NavCurrentUser)}
  {#if user.avatar_url}
    <img
      src={user.avatar_url}
      alt={`${user.display_name}'s avatar`}
      width="32"
      height="32"
      class="aspect-square rounded-full outline outline-1 -outline-offset-1 outline-[rgba(255,255,255,0.1)]"
      loading="lazy"
    />
  {/if}
{/snippet}

{#snippet userCountry(user: NavCurrentUser)}
  {#if user.country_code}
    <span
      class="flex items-center"
      title={user.country_name || user.country_code}
    >
      <CountryFlag
        countryCode={user.country_code}
        countryName={user.country_name}
      />
    </span>
  {/if}
{/snippet}

{#snippet userStreak(user: NavCurrentUser)}
  {#if user.streak_days && user.streak_days > 0}
    {@const streak = streakTheme(user.streak_days)}
    <div
      class={`group inline-flex items-center gap-1 rounded-lg bg-gradient-to-r px-2 py-1 transition-[background-color,border-color,color,box-shadow] duration-200 ${streak.bg} border ${streak.bc} ${streak.hbg}`}
      title={user.streak_days > 30
        ? "30+ daily streak"
        : `${user.streak_days} day streak`}
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        width="24"
        height="24"
        viewBox="0 0 24 24"
        class={`${streak.ic} transition-colors duration-200 group-hover:animate-pulse`}
      >
        <path
          fill="currentColor"
          d="M10 2c0-.88 1.056-1.331 1.692-.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08.174l.012.003c.625.133 1.203-.43 2.303-2.173l.14-.224a1 1 0 0 1 1.582-.153C18.733 9.46 20 12.402 20 14.295C20 18.56 16.409 22 12 22s-8-3.44-8-7.706c0-2.252 1.022-4.716 2.632-6.301l.605-.589c.241-.236.434-.43.618-.624C9.285 5.268 10 3.856 10 2"
        ></path>
      </svg>

      <span
        class={`text-md font-semibold tabular-nums ${streak.tc} transition-colors duration-200`}
      >
        {streakLabel(user.streak_days)}
        <span class={`ml-1 font-normal ${streak.tm}`}>day streak</span>
      </span>
    </div>
  {/if}
{/snippet}

{#snippet currentUserSummary(user: NavCurrentUser)}
  <div class="user-info flex min-h-10 items-center gap-2" title={user.title}>
    {@render userAvatar(user)}
    <span class="inline-flex items-center gap-1">{user.display_name}</span>
    {@render userCountry(user)}
  </div>

  {@render userStreak(user)}

  {@const adminMeta = adminMetaFor(user.admin_level)}
  {#if adminMeta}
    <span class={`${adminMeta.class} font-semibold px-2`}>
      {adminMeta.label}
    </span>
  {/if}
{/snippet}

{#if flashVisible && visibleFlash.length > 0}
  <div
    class="fixed top-4 left-1/2 transform -translate-x-1/2 z-50 w-full max-w-md px-4 space-y-2"
  >
    {#each visibleFlash as item}
      <div
        class={`flash-message shadow-lg flash-message--enter ${flashHiding ? "flash-message--leaving" : ""} ${item.class_name}`}
      >
        {item.message}
      </div>
    {/each}
  </div>
{/if}

{#if layout.nav.user_present}
  <Button
    type="button"
    unstyled
    class="mobile-nav-button"
    aria-label="Toggle navigation menu"
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
    aria-label="Close navigation menu"
  ></Button>

  <aside
    class="flex min-h-screen w-52 flex-col overflow-y-auto rounded-r-2xl bg-dark px-3 py-4 text-surface-content shadow-[4px_0_24px_rgba(0,0,0,0.16),inset_-1px_0_0_rgba(255,255,255,0.06)] lg:block"
    data-nav-target="nav"
    class:open={navOpen}
    style="scrollbar-width: none; -ms-overflow-style: none;"
  >
    <div class="space-y-4">
      {#if layout.nav.user_present}
        <div
          class="flex flex-col items-center gap-2 rounded-xl px-2 pb-3 shadow-[0_1px_0_rgba(255,255,255,0.08)]"
        >
          {#if layout.nav.current_user}
            {@render currentUserSummary(layout.nav.current_user)}
          {/if}
        </div>
      {:else}
        <div>
          <a
            href={layout.nav.login_path}
            class="block px-4 py-2 rounded-md transition text-on-primary font-semibold bg-primary hover:bg-secondary text-center"
            >Login</a
          >
        </div>
      {/if}

      <nav class="space-y-1">
        {#each layout.nav.links as link}
          {@render navItem(link)}
        {/each}

        {#if hasAdminLinks()}
          <div
            class="mt-2 space-y-1 pt-2 shadow-[0_-1px_0_rgba(255,255,255,0.08)]"
          >
            {#each adminLinkSections() as { links, toolClass }}
              {#each links as link}
                {@render navItem(link, toolClass)}
              {/each}
            {/each}
          </div>
        {/if}
      </nav>
    </div>
  </aside>
{/if}

<main
  class={`min-h-screen min-w-0 flex-1 transition-[margin] duration-300 ease-in-out ${layout.nav.user_present ? "lg:ml-62.5" : ""}`}
>
  <div class="mx-auto w-full min-w-0 max-w-7xl p-4 pt-16 md:p-8 lg:pt-8">
    {@render children?.()}

    <footer
      class="relative w-full mt-12 mb-5 p-2.5 text-center text-xs text-text-muted"
    >
      <div class="container mx-auto">
        <p
          class="brightness-60 hover:brightness-100 transition-all duration-200"
        >
          Using Inertia. Build <a
            href={layout.footer.commit_link}
            class="text-inherit underline opacity-80 hover:opacity-100 transition-opacity duration-200"
            >{layout.footer.git_version}</a
          >
          from {layout.footer.server_start_time_ago} ago. {footerStatsText()}
        </p>
        {#if layout.show_stop_impersonating}
          <a
            href={layout.stop_impersonating_path}
            data-turbo-prefetch="false"
            class="text-primary font-bold hover:text-red transition-colors duration-200"
            >Stop impersonating</a
          >
        {/if}
      </div>
      <div class="flex flex-row gap-2 mt-4 justify-center">
        {#each layout.footer.active_users_graph as hour, hourIndex}
          <div
            class="bg-white opacity-10 grow max-w-1 rounded-sm"
            title={activeUsersGraphTitle(hourIndex, hour.users)}
            style={`height: ${hour.height}px`}
          ></div>
        {/each}
      </div>
    </footer>
  </div>
</main>

{#if layout.currently_hacking}
  <CurrentlyHackingPanel currentlyHacking={layout.currently_hacking} />
{/if}

<Modal
  bind:open={logoutOpen}
  title="Woah, hold on a sec!"
  description="You sure you want to log out? You can sign back in later but that is a bit of a hassle..."
  maxWidth="max-w-lg"
  hasIcon
  hasActions
>
  {#snippet icon()}
    <svg
      class="h-8 w-8"
      fill="none"
      stroke="currentColor"
      viewBox="0 0 24 24"
      aria-hidden="true"
    >
      <path
        fill="currentColor"
        d="M5 21q-.825 0-1.412-.587T3 19v-3q0-.425.288-.712T4 15t.713.288T5 16v3h14V5H5v3q0 .425-.288.713T4 9t-.712-.288T3 8V5q0-.825.588-1.412T5 3h14q.825 0 1.413.588T21 5v14q0 .825-.587 1.413T19 21zm6.65-8H4q-.425 0-.712-.288T3 12t.288-.712T4 11h7.65L9.8 9.15q-.3-.3-.288-.7t.288-.7q.3-.3.713-.312t.712.287L14.8 11.3q.15.15.213.325t.062.375t-.062.375t-.213.325l-3.575 3.575q-.3.3-.712.288T9.8 16.25q-.275-.3-.288-.7t.288-.7z"
      />
    </svg>
  {/snippet}

  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        onclick={closeLogout}
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted">Go back</Button
      >

      <form method="post" action={layout.signout_path} class="m-0">
        <input
          type="hidden"
          name="authenticity_token"
          value={layout.csrf_token}
        />
        <input type="hidden" name="_method" value="delete" />
        <Button
          type="submit"
          variant="primary"
          class="h-10 w-full text-on-primary">Log out now</Button
        >
      </form>
    </div>
  {/snippet}
</Modal>

<style>
  :global(#app) {
    display: flex;
    flex: 1 1 auto;
    min-height: 100vh;
    width: 100%;
  }
</style>
