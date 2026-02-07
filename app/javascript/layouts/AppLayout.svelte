<script lang="ts">
  import { onMount, onDestroy } from "svelte";

  type NavLink = {
    label: string;
    href?: string;
    active?: boolean;
    badge?: number | null;
    action?: string;
  };

  type LayoutNav = {
    flash: { message: string; class_name: string }[];
    user_present: boolean;
    user_mention_html?: string | null;
    streak_html?: string | null;
    admin_level_html?: string | null;
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
      count_url: string;
      full_url: string;
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
  let currentlyVisible = $state(false);
  let currentlyExpanded = $state(false);
  let currentlyLoading = $state(false);
  let currentlyUsers = $state<CurrentlyHackingUser[]>([]);
  let currentlyCount = $state(0);
  let currentlyError = $state(false);

  let countInterval: ReturnType<typeof setInterval> | null = null;

  const closeNav = () => {
    navOpen = false;
  };

  const toggleNav = () => {
    navOpen = !navOpen;
  };

  const handleNavLinkClick = () => {
    if (!isBrowser) return;
    if (window.innerWidth <= 1024) {
      closeNav();
    }
  };

  const closeLogout = () => {
    logoutOpen = false;
  };

  const openLogout = () => {
    logoutOpen = true;
  };

  const handleResize = () => {
    if (!isBrowser) return;
    if (window.innerWidth > 1024) {
      closeNav();
    }
  };

  const handleKeydown = (event: KeyboardEvent) => {
    if (event.key === "Escape") {
      closeNav();
      closeLogout();
    }
  };

  const pluralize = (count: number, word: string) => {
    return `${count} ${count === 1 ? word : `${word}s`}`;
  };

  const countLabel = () => {
    const label = currentlyCount === 1 ? "person" : "people";
    return `${currentlyCount} ${label} currently hacking`;
  };

  const visualizeGitUrl = (url?: string | null) => {
    if (!url) return "";
    if (!url.startsWith("https://github.com/")) return "";
    return url.replace(
      "https://github.com/",
      "https://tkww0gcc0gkwwo4gc8kgs0sw.a.selfhosted.hackclub.com/",
    );
  };

  const pollCount = async () => {
    if (!layout?.currently_hacking?.count_url) return;
    try {
      const response = await fetch(layout.currently_hacking.count_url, {
        headers: { Accept: "application/json" },
      });
      if (response.ok) {
        const data = await response.json();
        currentlyCount = data.count;
        currentlyVisible = true;
      }
    } catch (error) {
      console.error(error);
    }
  };

  const startCountPolling = () => {
    stopCountPolling();
    pollCount();
    countInterval = setInterval(pollCount, layout.currently_hacking.interval);
  };

  const stopCountPolling = () => {
    if (countInterval) {
      clearInterval(countInterval);
      countInterval = null;
    }
  };

  const loadCurrentlyHacking = async () => {
    if (!layout?.currently_hacking?.full_url) return;
    currentlyLoading = true;
    currentlyError = false;
    try {
      const response = await fetch(layout.currently_hacking.full_url, {
        headers: { Accept: "application/json" },
      });
      if (response.ok) {
        const data = await response.json();
        currentlyUsers = data.users || [];
      } else {
        currentlyError = true;
      }
    } catch (error) {
      console.error("Failed to poll currently hacking:", error);
      currentlyError = true;
    } finally {
      currentlyLoading = false;
    }
  };

  const toggleCurrentlyHacking = async () => {
    currentlyExpanded = !currentlyExpanded;
    if (currentlyExpanded) {
      await loadCurrentlyHacking();
    }
  };

  $effect(() => {
    if (isBrowser) {
      document.body.classList.toggle("overflow-hidden", navOpen);
    }
  });

  onMount(() => {
    if (!isBrowser) return;
    handleResize();
    window.addEventListener("resize", handleResize);
    document.addEventListener("keydown", handleKeydown);
    startCountPolling();
  });

  onDestroy(() => {
    stopCountPolling();
    if (isBrowser) {
      window.removeEventListener("resize", handleResize);
      document.removeEventListener("keydown", handleKeydown);
    }
  });
</script>

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
    class="flex flex-col min-h-screen w-62.5 bg-dark text-white px-2 py-4 rounded-r-lg overflow-y-auto lg:block"
    data-nav-target="nav"
    class:open={navOpen}
    style="scrollbar-width: none; -ms-overflow-style: none;"
  >
    <div class="space-y-4">
      {#if layout.nav.flash.length > 0}
        <div>
          {#each layout.nav.flash as item}
            <div
              class={`rounded-lg border text-center text-lg px-3 py-2 mb-2 ${item.class_name}`}
            >
              {item.message}
            </div>
          {/each}
        </div>
      {/if}
      {#if layout.nav.user_present}
        <div class="px-2 rounded-lg flex flex-col items-center gap-2">
          {#if layout.nav.user_mention_html}
            {@html layout.nav.user_mention_html}
          {/if}
          {#if layout.nav.streak_html}
            {@html layout.nav.streak_html}
          {/if}
          {#if layout.nav.admin_level_html}
            {@html layout.nav.admin_level_html}
          {/if}
        </div>
      {:else}
        <div class="mb-1">
          <a
            href={layout.nav.login_path}
            class="block px-2 py-1 rounded-lg transition text-white font-bold bg-primary hover:bg-secondary text-lg"
            >Login</a
          >
        </div>
      {/if}

      <div>
        <div class="space-y-1 text-lg">
          {#each layout.nav.links as link}
            <div>
              {#if link.action === "logout"}
                <button
                  type="button"
                  onclick={openLogout}
                  class="w-full text-left cursor-pointer block px-3.75 py-2.5 rounded-lg transition hover:text-primary hover:bg-darkless"
                  >Logout</button
                >
              {:else}
                <a
                  href={link.href}
                  onclick={handleNavLinkClick}
                  class={`block px-2 py-1 rounded-lg transition ${link.active ? "bg-primary text-primary" : "hover:bg-darkless"}`}
                >
                  {link.label}
                </a>
              {/if}
            </div>
          {/each}

          {#each layout.nav.dev_links as link}
            <div class="dev-tool">
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class={`block px-2 py-1 rounded-lg transition ${link.active ? "bg-primary text-primary" : "hover:bg-darkless"}`}
              >
                {link.label}
              </a>
            </div>
          {/each}

          {#each layout.nav.admin_links as link}
            <div class="admin-tool">
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class={`block px-2 py-1 rounded-lg transition ${link.active ? "bg-primary text-primary" : "hover:bg-darkless"}`}
              >
                {link.label}
              </a>
            </div>
          {/each}

          {#each layout.nav.viewer_links as link}
            <div class="viewer-tool">
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class={`block px-2 py-1 rounded-lg transition ${link.active ? "bg-primary text-primary" : "hover:bg-darkless"}`}
              >
                {link.label}
              </a>
            </div>
          {/each}

          {#each layout.nav.superadmin_links as link}
            <div class="superadmin-tool">
              <a
                href={link.href}
                onclick={handleNavLinkClick}
                class={`block px-2 py-1 rounded-lg transition ${link.active ? "bg-primary text-primary" : "hover:bg-darkless"}`}
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-2 py-0.5 text-xs rounded-full bg-primary text-white font-semibold"
                    >{link.badge}</span
                  >
                {/if}
              </a>
            </div>
          {/each}

          {#if layout.nav.activities_html}
            {@html layout.nav.activities_html}
          {/if}
        </div>
      </div>
    </div>
  </aside>
{/if}

<main
  class={`flex-1 p-5 mb-25 pt-16 lg:pt-5 transition-all duration-300 ease-in-out ${layout.nav.user_present ? "lg:ml-25 lg:max-w-[calc(100%-250px)]" : ""}`}
>
  {@render children?.()}
  <footer
    class="relative w-full mt-12 mb-5 p-2.5 text-center text-xs text-gray-600 hover:text-gray-300 transition-colors duration-200"
  >
    <div class="container">
      <p>
        Using Inertia. Build <a
          href={layout.footer.commit_link}
          class="text-inherit underline opacity-80 hover:opacity-100 transition-opacity duration-200"
          >{layout.footer.git_version}</a
        >
        from {layout.footer.server_start_time_ago} ago.
        {pluralize(layout.footer.heartbeat_recent_count, "heartbeat")}
        ({layout.footer.heartbeat_recent_imported_count} imported) in the past 24
        hours. (DB: {pluralize(layout.footer.query_count, "query")}, {layout
          .footer.query_cache_count} cached) (CACHE: {layout.footer.cache_hits} hits,
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
    <div class="flex flex-row gap-2 mt-4">
      {#each layout.footer.active_users_graph as hour}
        <div
          class="bg-white opacity-10 grow min-w-2.5"
          title={hour.title}
          style={`height: ${hour.height}px`}
        ></div>
      {/each}
    </div>
  </footer>
</main>

<div
  class="fixed top-0 right-5 max-w-sm max-h-[80vh] bg-elevated border border-darkless rounded-b-xl shadow-lg z-1000 overflow-hidden transform transition-transform duration-300 ease-out"
  class:hidden={!currentlyVisible}
  class:-translate-y-full={!currentlyVisible}
  class:translate-y-0={currentlyVisible}
>
  <div
    class="currently-hacking p-3 bg-elevated cursor-pointer select-none bg-dark flex items-center justify-between"
    onclick={toggleCurrentlyHacking}
  >
    <div class="text-white text-sm font-medium">
      <div class="flex items-center">
        <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse mr-2"></div>
        <span class="text-lg">{countLabel()}</span>
      </div>
    </div>
  </div>
  {#if currentlyExpanded}
    {#if currentlyLoading}
      <div class="p-4">
        <div class="text-center text-muted text-md">Loading...</div>
      </div>
    {:else if currentlyError}
      <div class="p-4 bg-elevated">
        <div class="text-center text-muted text-sm">
          ruh ro, something broke :(
        </div>
      </div>
    {:else if currentlyUsers.length === 0}
      <div class="p-4 bg-elevated">
        <div class="text-center text-muted text-sm italic">
          No one is currently hacking :(
        </div>
      </div>
    {:else}
      <div
        class="currently-hacking-list max-h-[60vh] max-w-100 overflow-y-auto p-1 bg-darker"
      >
        <div class="space-y-1">
          {#each currentlyUsers as user}
            <div class="flex flex-col space-y-1 p-1">
              <div class="flex items-center">
                <div class="user-info flex items-center gap-2">
                  {#if user.avatar_url}
                    <img
                      src={user.avatar_url}
                      alt={`${user.display_name || `User ${user.id}`}'s avatar`}
                      class="w-6 h-6 rounded-full aspect-square"
                      loading="lazy"
                    />
                  {/if}
                  <span class="inline-flex items-center gap-1">
                    {#if user.slack_uid}
                      <a
                        href={`https://hackclub.slack.com/team/${user.slack_uid}`}
                        target="_blank"
                        class="text-blue-500 hover:underline"
                        >@{user.display_name || `User ${user.id}`}</a
                      >
                    {:else}
                      <span class="text-white"
                        >{user.display_name || `User ${user.id}`}</span
                      >
                    {/if}
                  </span>
                </div>
              </div>
              {#if user.active_project}
                <div class="text-sm italic text-muted ml-2">
                  working on
                  {#if user.active_project.repo_url}
                    <a
                      href={user.active_project.repo_url}
                      target="_blank"
                      class="text-accent hover:text-cyan-400 transition-colors"
                      >{user.active_project.name}</a
                    >
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

<div
  class="fixed inset-0 flex items-center justify-center z-9999 transition-opacity duration-300 ease-in-out"
  class:opacity-0={!logoutOpen}
  class:pointer-events-none={!logoutOpen}
  style="background-color: rgba(0, 0, 0, 0.5);backdrop-filter: blur(4px);"
  onclick={(event) => {
    if (event.target === event.currentTarget) closeLogout();
  }}
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
