<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import { usePoll } from "@inertiajs/svelte";
  import { onMount, onDestroy } from "svelte";
  import plur from "plur";
  import NavAdminLevelBadge from "../components/nav/NavAdminLevelBadge.svelte";
  import NavStreakBadge from "../components/nav/NavStreakBadge.svelte";
  import NavUserMention from "../components/nav/NavUserMention.svelte";

  type NavLink = {
    label: string;
    href?: string;
    active?: boolean;
    badge?: number | null;
    action?: string;
  };

  type NavUserMentionType = {
    display_name: string;
    avatar_url?: string | null;
    title?: string | null;
    country_code?: string | null;
    country_name?: string | null;
  };

  type NavStreak = {
    count: number;
    display: string;
    title: string;
    show_text?: boolean;
    icon_size?: number;
    show_super_class?: boolean;
  };

  type LayoutNav = {
    flash: { message: string; class_name: string }[];
    user_present: boolean;
    user?: NavUserMentionType | null;
    streak?: NavStreak | null;
    admin_level?: string | null;
    login_path: string;
    links: NavLink[];
    dev_links: NavLink[];
    admin_links: NavLink[];
    viewer_links: NavLink[];
    superadmin_links: NavLink[];
    activities_html?: string | null;
  };

  type Footer = {
    git_version: string;
    commit_link: string;
    server_start_time_ago: string;
    heartbeat_recent_count: number;
    heartbeat_recent_imported_count: number;
    query_count: number;
    query_cache_count: number;
    cache_hits: number;
    cache_misses: number;
    requests_per_second: string;
    active_users_graph: { height: number; title: string }[];
  };

  type CurrentlyHackingUser = {
    id: number;
    display_name?: string;
    slack_uid?: string;
    avatar_url?: string;
    active_project?: { name: string; repo_url?: string | null };
  };

  type LayoutProps = {
    nav: LayoutNav;
    footer: Footer;
    currently_hacking: {
      count: number;
      users: CurrentlyHackingUser[];
      interval: number;
    };
    csrf_token: string;
    signout_path: string;
    show_stop_impersonating: boolean;
    stop_impersonating_path: string;
  };

  let { layout, children }: { layout: LayoutProps; children?: () => unknown } =
    $props();

  const isBrowser =
    typeof window !== "undefined" && typeof document !== "undefined";

  let navOpen = $state(false);
  let logoutOpen = $state(false);
  let currentlyExpanded = $state(false);
  let flashVisible = $state(layout.nav.flash.length > 0);
  let flashHiding = $state(false);
  const flashHideDelay = 6000;
  const flashExitDuration = 250;

  const toggleNav = () => (navOpen = !navOpen);
  const closeNav = () => (navOpen = false);
  const openLogout = () => (logoutOpen = true);
  const closeLogout = () => (logoutOpen = false);

  usePoll(layout.currently_hacking?.interval || 30000, {
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

  const countLabel = () =>
    `${layout.currently_hacking.count} ${plur("person", layout.currently_hacking.count)} currently hacking`;

  const visualizeGitUrl = (url?: string | null) =>
    url?.startsWith("https://github.com/")
      ? url.replace(
          "https://github.com/",
          "https://tkww0gcc0gkwwo4gc8kgs0sw.a.selfhosted.hackclub.com/",
        )
      : "";

  const toggleCurrentlyHacking = () => {
    currentlyExpanded = !currentlyExpanded;
  };

  $effect(() => {
    if (isBrowser) document.body.classList.toggle("overflow-hidden", navOpen);
  });

  $effect(() => {
    if (!layout.nav.flash.length) {
      flashVisible = false;
      flashHiding = false;
      return;
    }

    flashVisible = true;
    flashHiding = false;
    let removeTimeoutId: ReturnType<typeof setTimeout> | undefined;
    const hideTimeoutId = setTimeout(() => {
      flashHiding = true;
      removeTimeoutId = setTimeout(() => {
        flashVisible = false;
        flashHiding = false;
      }, flashExitDuration);
    }, flashHideDelay);

    return () => {
      clearTimeout(hideTimeoutId);
      if (removeTimeoutId) clearTimeout(removeTimeoutId);
    };
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
    `block px-3 py-2 rounded-md text-sm transition-colors ${active ? "bg-primary text-white" : "hover:bg-darkless"}`;
</script>

{#if flashVisible && layout.nav.flash.length > 0}
  <div
    class="fixed top-4 left-1/2 transform -translate-x-1/2 z-50 w-full max-w-md px-4 space-y-2"
  >
    {#each layout.nav.flash as item}
      <div
        class={`flash-message shadow-lg flash-message--enter ${flashHiding ? "flash-message--leaving" : ""} ${item.class_name}`}
      >
        {item.message}
      </div>
    {/each}
  </div>
{/if}

{#if layout.nav.user_present}
  <button
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
  </button>
  <div class="nav-overlay" class:open={navOpen} onclick={closeNav}></div>

  <aside
    class="flex flex-col min-h-screen w-52 bg-dark text-white px-3 py-4 rounded-r-lg overflow-y-auto lg:block"
    data-nav-target="nav"
    class:open={navOpen}
    style="scrollbar-width: none; -ms-overflow-style: none;"
  >
    <div class="space-y-4">
      {#if layout.nav.user_present}
        <div
          class="flex flex-col items-center gap-2 pb-3 border-b border-darkless"
        >
          {#if layout.nav.user}
            <NavUserMention user={layout.nav.user} />
          {/if}
          {#if layout.nav.streak}
            <NavStreakBadge streak={layout.nav.streak} />
          {/if}
          {#if layout.nav.admin_level}
            <NavAdminLevelBadge level={layout.nav.admin_level} />
          {/if}
        </div>
      {:else}
        <div>
          <a
            href={layout.nav.login_path}
            class="block px-4 py-2 rounded-md transition text-white font-semibold bg-primary hover:bg-secondary text-center"
            >Login</a
          >
        </div>
      {/if}

      <nav class="space-y-1">
        {#each layout.nav.links as link}
          {#if link.action === "logout"}
            <a
              type="button"
              onclick={openLogout}
              class={`${navLinkClass(false)} cursor-pointer`}>Logout</a
            >
          {:else}
            <a
              href={link.href}
              onclick={handleNavLinkClick}
              class={navLinkClass(link.active)}>{link.label}</a
            >
          {/if}
        {/each}

        {#if layout.nav.dev_links.length > 0 || layout.nav.admin_links.length > 0 || layout.nav.viewer_links.length > 0 || layout.nav.superadmin_links.length > 0}
          <div class="pt-2 mt-2 border-t border-darkless space-y-1">
            {#each layout.nav.dev_links as link}
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} dev-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-white font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </a>
            {/each}

            {#each layout.nav.admin_links as link}
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} admin-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-white font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </a>
            {/each}

            {#each layout.nav.viewer_links as link}
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} viewer-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-white font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </a>
            {/each}

            {#each layout.nav.superadmin_links as link}
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} superadmin-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-white font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </a>
            {/each}
          </div>
        {/if}

        {#if layout.nav.activities_html}
          <div class="pt-2">{@html layout.nav.activities_html}</div>
        {/if}
      </nav>
    </div>
  </aside>
{/if}

<main
  class={`flex-1 min-h-screen transition-all duration-300 ease-in-out ${layout.nav.user_present ? "lg:ml-62.5" : ""}`}
>
  <div class="w-full max-w-7xl mx-auto p-4 pt-16 lg:pt-8 md:p-8">
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
          from {layout.footer.server_start_time_ago} ago.
          {plur("heartbeat", layout.footer.heartbeat_recent_count)}
          ({layout.footer.heartbeat_recent_imported_count} imported) in the past
          24 hours. (DB: {layout.footer.query_count}
          {plur("query", layout.footer.query_count)}, {layout.footer
            .query_cache_count} cached) (CACHE: {layout.footer.cache_hits} hits,
          {layout.footer.cache_misses} misses) ({layout.footer
            .requests_per_second})
        </p>
        {#if layout.show_stop_impersonating}
          <a
            href={layout.stop_impersonating_path}
            data-turbo-prefetch="false"
            class="text-primary font-bold hover:text-red-300 transition-colors duration-200"
            >Stop impersonating</a
          >
        {/if}
      </div>
      <div class="flex flex-row gap-2 mt-4 justify-center">
        {#each layout.footer.active_users_graph as hour}
          <div
            class="bg-white opacity-10 grow max-w-1 rounded-sm"
            title={hour.title}
            style={`height: ${hour.height}px`}
          ></div>
        {/each}
      </div>
    </footer>
  </div>
</main>

{#if layout.currently_hacking}
  <div
    class="fixed top-0 right-5 max-w-sm max-h-[80vh] bg-dark border border-darkless rounded-b-xl shadow-lg z-1000 overflow-hidden transform transition-transform duration-300 ease-out"
  >
    <div
      class="currently-hacking p-3 bg-dark cursor-pointer select-none flex items-center justify-between"
      onclick={toggleCurrentlyHacking}
    >
      <div class="text-white text-sm font-medium">
        <div class="flex items-center">
          <div
            class="w-2 h-2 rounded-full bg-green-500 animate-pulse mr-2"
          ></div>
          <span class="text-base">{countLabel()}</span>
        </div>
      </div>
    </div>

    {#if currentlyExpanded}
      {#if layout.currently_hacking.users.length === 0}
        <div class="p-4 bg-dark">
          <div class="text-center text-muted text-sm italic">
            No one is currently hacking :(
          </div>
        </div>
      {:else}
        <div
          class="currently-hacking-list max-h-[60vh] max-w-100 overflow-y-auto p-2 bg-darker"
        >
          <div class="space-y-2">
            {#each layout.currently_hacking.users as user}
              <div
                class="flex flex-col space-y-1 p-2 rounded-md hover:bg-dark transition-colors"
              >
                <div class="flex items-center gap-2">
                  {#if user.avatar_url}
                    <img
                      src={user.avatar_url}
                      alt={`${user.display_name || `User ${user.id}`}'s avatar`}
                      class="w-6 h-6 rounded-full aspect-square flex-shrink-0"
                      loading="lazy"
                    />
                  {/if}
                  {#if user.slack_uid}
                    <a
                      href={`https://hackclub.slack.com/team/${user.slack_uid}`}
                      target="_blank"
                      class="text-blue-500 hover:underline text-sm"
                    >
                      @{user.display_name || `User ${user.id}`}
                    </a>
                  {:else}
                    <span class="text-white text-sm"
                      >{user.display_name || `User ${user.id}`}</span
                    >
                  {/if}
                </div>
                {#if user.active_project}
                  <div class="text-xs text-muted ml-8">
                    working on
                    {#if user.active_project.repo_url}
                      <a
                        href={user.active_project.repo_url}
                        target="_blank"
                        class="text-accent hover:text-cyan-400 transition-colors"
                      >
                        {user.active_project.name}
                      </a>
                    {:else}
                      {user.active_project.name}
                    {/if}
                    {#if visualizeGitUrl(user.active_project.repo_url)}
                      <a
                        href={visualizeGitUrl(user.active_project.repo_url)}
                        target="_blank"
                        class="ml-1">🌌</a
                      >
                    {/if}
                  </div>
                {/if}
              </div>
            {/each}
          </div>
        </div>
      {/if}
    {/if}
  </div>
{/if}

<div
  class="fixed inset-0 flex items-center justify-center z-9999 transition-opacity duration-300 ease-in-out"
  class:opacity-0={!logoutOpen}
  class:pointer-events-none={!logoutOpen}
  style="background-color: rgba(0, 0, 0, 0.5);backdrop-filter: blur(4px);"
  onclick={(e) => e.target === e.currentTarget && closeLogout()}
>
  <div
    class={`bg-dark border border-primary rounded-lg p-6 max-w-md w-full mx-4 flex flex-col items-center justify-center transform transition-transform duration-300 ease-in-out ${logoutOpen ? "scale-100" : "scale-95"}`}
  >
    <div class="flex flex-col items-center w-full">
      <div class="mb-4 flex justify-center w-full">
        <svg
          class="w-12 h-12 text-primary"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            fill="currentColor"
            d="M5 21q-.825 0-1.412-.587T3 19v-3q0-.425.288-.712T4 15t.713.288T5 16v3h14V5H5v3q0 .425-.288.713T4 9t-.712-.288T3 8V5q0-.825.588-1.412T5 3h14q.825 0 1.413.588T21 5v14q0 .825-.587 1.413T19 21zm6.65-8H4q-.425 0-.712-.288T3 12t.288-.712T4 11h7.65L9.8 9.15q-.3-.3-.288-.7t.288-.7q.3-.3.713-.312t.712.287L14.8 11.3q.15.15.213.325t.062.375t-.062.375t-.213.325l-3.575 3.575q-.3.3-.712.288T9.8 16.25q-.275-.3-.288-.7t.288-.7z"
          />
        </svg>
      </div>

      <h3 class="text-2xl font-bold text-white mb-2 text-center w-full">
        Woah hold on a sec
      </h3>
      <p class="text-gray-300 mb-6 text-center w-full">
        You sure you want to log out? You can sign back in later but that is a
        bit of a hassle...
      </p>

      <div class="flex w-full gap-3">
        <div class="flex-1 min-w-0">
          <button
            type="button"
            onclick={closeLogout}
            class="w-full h-10 px-4 rounded-lg transition-colors duration-200 cursor-pointer m-0 bg-dark hover:bg-darkless border border-darkless text-gray-300"
            >Go back</button
          >
        </div>
        <div class="flex-1 min-w-0">
          <form method="post" action={layout.signout_path} class="m-0">
            <input
              type="hidden"
              name="authenticity_token"
              value={layout.csrf_token}
            />
            <input type="hidden" name="_method" value="delete" />
            <button
              type="submit"
              class="w-full h-10 px-4 rounded-lg transition-colors duration-200 font-medium cursor-pointer m-0 bg-primary hover:bg-primary/75 text-white"
              >Log out now</button
            >
          </form>
        </div>
      </div>
    </div>
  </div>
</div>

<style>
  :global(#app) {
    display: flex;
    flex: 1 1 auto;
    min-height: 100vh;
    width: 100%;
  }
</style>
