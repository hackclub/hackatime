<script lang="ts">
  import { Link, router, usePoll } from "@inertiajs/svelte";
  import type { Snippet } from "svelte";
  import { onMount, onDestroy } from "svelte";
  import plur from "plur";

  type NavLink = {
    label: string;
    href?: string;
    active?: boolean;
    badge?: number | null;
    action?: string;
  };

  type AdminLevel = "default" | "superadmin" | "admin" | "viewer";

  type NavCurrentUser = {
    display_name: string;
    avatar_url?: string | null;
    title: string;
    country_code?: string | null;
    country_name?: string | null;
    streak_days?: number | null;
    admin_level: AdminLevel;
  };

  type LayoutNav = {
    flash: { message: string; class_name: string }[];
    user_present: boolean;
    current_user?: NavCurrentUser | null;
    login_path: string;
    links: NavLink[];
    dev_links: NavLink[];
    admin_links: NavLink[];
    viewer_links: NavLink[];
    superadmin_links: NavLink[];
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
    active_users_graph: { height: number; users: number }[];
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
    theme: {
      name: string;
      color_scheme: "dark" | "light";
      theme_color: string;
    };
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

  let { layout, children }: { layout: LayoutProps; children?: Snippet } =
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

  const countryFlagEmoji = (countryCode?: string | null) => {
    if (!countryCode) return "";
    return countryCode
      .toUpperCase()
      .replace(/./g, (char) =>
        String.fromCodePoint(127397 + char.charCodeAt(0)),
      );
  };

  const streakThemeClasses = (streakDays: number) => {
    if (streakDays >= 30) {
      return {
        bg: "from-blue/20 to-purple/20",
        hbg: "hover:from-blue/30 hover:to-purple/30",
        bc: "border-blue",
        ic: "text-blue group-hover:text-blue",
        tc: "text-blue group-hover:text-blue",
        tm: "text-blue",
      };
    }

    if (streakDays >= 7) {
      return {
        bg: "from-red/20 to-orange/20",
        hbg: "hover:from-red/30 hover:to-orange/30",
        bc: "border-red",
        ic: "text-red group-hover:text-red",
        tc: "text-red group-hover:text-red",
        tm: "text-red",
      };
    }

    return {
      bg: "from-orange/20 to-yellow/20",
      hbg: "hover:from-orange/30 hover:to-yellow/30",
      bc: "border-orange",
      ic: "text-orange group-hover:text-orange",
      tc: "text-orange group-hover:text-orange",
      tm: "text-orange",
    };
  };

  const streakLabel = (streakDays: number) => (streakDays > 30 ? "30+" : `${streakDays}`);

  const adminLevelLabel = (adminLevel?: AdminLevel | null) => {
    if (adminLevel === "superadmin") return "Superadmin";
    if (adminLevel === "admin") return "Admin";
    if (adminLevel === "viewer") return "Viewer";
    return null;
  };

  const adminLevelClass = (adminLevel?: AdminLevel | null) => {
    if (adminLevel === "superadmin") return "text-red superadmin-tool";
    if (adminLevel === "admin") return "text-yellow admin-tool";
    if (adminLevel === "viewer") return "text-blue viewer-tool";
    return "";
  };

  const toggleCurrentlyHacking = () => {
    currentlyExpanded = !currentlyExpanded;
  };

  $effect(() => {
    if (isBrowser) document.body.classList.toggle("overflow-hidden", navOpen);
  });

  $effect(() => {
    if (!isBrowser || !layout.theme?.name) return;

    document.documentElement.setAttribute("data-theme", layout.theme.name);

    const colorSchemeMeta = document.querySelector(
      "meta[name='color-scheme']",
    );
    colorSchemeMeta?.setAttribute("content", layout.theme.color_scheme);

    const themeColorMeta = document.querySelector("meta[name='theme-color']");
    themeColorMeta?.setAttribute("content", layout.theme.theme_color);

    const tileColorMeta = document.querySelector(
      "meta[name='msapplication-TileColor']",
    );
    tileColorMeta?.setAttribute("content", layout.theme.theme_color);
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
    `block px-3 py-2 rounded-md text-sm transition-colors ${active ? "bg-primary text-on-primary" : "hover:bg-darkless"}`;
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
    class="flex flex-col min-h-screen w-52 bg-dark text-surface-content px-3 py-4 rounded-r-lg overflow-y-auto lg:block"
    data-nav-target="nav"
    class:open={navOpen}
    style="scrollbar-width: none; -ms-overflow-style: none;"
  >
    <div class="space-y-4">
      {#if layout.nav.user_present}
        <div
          class="flex flex-col items-center gap-2 pb-3 border-b border-darkless"
        >
          {#if layout.nav.current_user}
            <div class="user-info flex items-center gap-2" title={layout.nav.current_user.title}>
              {#if layout.nav.current_user.avatar_url}
                <img
                  src={layout.nav.current_user.avatar_url}
                  alt={`${layout.nav.current_user.display_name}'s avatar`}
                  width="32"
                  height="32"
                  class="rounded-full aspect-square border border-surface-200"
                  loading="lazy"
                />
              {/if}
              <span class="inline-flex items-center gap-1">
                {layout.nav.current_user.display_name}
              </span>
              {#if layout.nav.current_user.country_code}
                <span
                  class="flex items-center"
                  title={layout.nav.current_user.country_name || layout.nav.current_user.country_code}
                >
                  {countryFlagEmoji(layout.nav.current_user.country_code)}
                </span>
              {/if}
            </div>

            {#if layout.nav.current_user.streak_days && layout.nav.current_user.streak_days > 0}
              {@const streakTheme = streakThemeClasses(layout.nav.current_user.streak_days)}
              <div
                class={`inline-flex items-center gap-1 px-2 py-1 bg-gradient-to-r ${streakTheme.bg} border ${streakTheme.bc} rounded-lg transition-all duration-200 ${streakTheme.hbg} group`}
                title={layout.nav.current_user.streak_days > 30 ? "30+ daily streak" : `${layout.nav.current_user.streak_days} day streak`}
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  width="24"
                  height="24"
                  viewBox="0 0 24 24"
                  class={`${streakTheme.ic} transition-colors duration-200 group-hover:animate-pulse`}
                >
                  <path
                    fill="currentColor"
                    d="M10 2c0-.88 1.056-1.331 1.692-.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08.174l.012.003c.625.133 1.203-.43 2.303-2.173l.14-.224a1 1 0 0 1 1.582-.153C18.733 9.46 20 12.402 20 14.295C20 18.56 16.409 22 12 22s-8-3.44-8-7.706c0-2.252 1.022-4.716 2.632-6.301l.605-.589c.241-.236.434-.43.618-.624C9.285 5.268 10 3.856 10 2"
                  ></path>
                </svg>

                <span class={`text-md font-semibold ${streakTheme.tc} transition-colors duration-200`}>
                  {streakLabel(layout.nav.current_user.streak_days)}
                  <span class={`ml-1 font-normal ${streakTheme.tm}`}>day streak</span>
                </span>
              </div>
            {/if}

            {#if adminLevelLabel(layout.nav.current_user.admin_level)}
              <span
                class={`${adminLevelClass(layout.nav.current_user.admin_level)} font-semibold px-2`}
              >
                {adminLevelLabel(layout.nav.current_user.admin_level)}
              </span>
            {/if}
          {/if}
        </div>
      {:else}
        <div>
          <Link
            href={layout.nav.login_path}
            class="block px-4 py-2 rounded-md transition text-on-primary font-semibold bg-primary hover:bg-secondary text-center"
            >Login</Link
          >
        </div>
      {/if}

      <nav class="space-y-1">
        {#each layout.nav.links as link}
          {#if link.action === "logout"}
            <Link
              href="#"
              type="button"
              onclick={(event) => {
                event.preventDefault();
                openLogout();
              }}
              class={`${navLinkClass(false)} cursor-pointer`}>Logout</Link
            >
          {:else}
            <Link
              href={link.href}
              onclick={handleNavLinkClick}
              class={navLinkClass(link.active)}>{link.label}</Link
            >
          {/if}
        {/each}

        {#if layout.nav.dev_links.length > 0 || layout.nav.admin_links.length > 0 || layout.nav.viewer_links.length > 0 || layout.nav.superadmin_links.length > 0}
          <div class="pt-2 mt-2 border-t border-darkless space-y-1">
            {#each layout.nav.dev_links as link}
              <Link
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} dev-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </Link>
            {/each}

            {#each layout.nav.admin_links as link}
              <Link
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} admin-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </Link>
            {/each}

            {#each layout.nav.viewer_links as link}
              <Link
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} viewer-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </Link>
            {/each}

            {#each layout.nav.superadmin_links as link}
              <Link
                href={link.href}
                onclick={handleNavLinkClick}
                class="{navLinkClass(link.active)} superadmin-tool"
              >
                {link.label}
                {#if link.badge}
                  <span
                    class="ml-1 px-1.5 py-0.5 text-xs rounded-full bg-primary text-on-primary font-medium"
                  >
                    {link.badge}
                  </span>
                {/if}
              </Link>
            {/each}
          </div>
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
          Using Inertia. Build <Link
            href={layout.footer.commit_link}
            class="text-inherit underline opacity-80 hover:opacity-100 transition-opacity duration-200"
            >{layout.footer.git_version}</Link
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
          <Link
            href={layout.stop_impersonating_path}
            data-turbo-prefetch="false"
            class="text-primary font-bold hover:text-red transition-colors duration-200"
            >Stop impersonating</Link
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
  <div
    class="fixed top-0 right-5 max-w-sm max-h-[80vh] bg-dark border border-darkless rounded-b-xl shadow-lg z-1000 overflow-hidden transform transition-transform duration-300 ease-out"
  >
    <div
      class="currently-hacking p-3 bg-dark cursor-pointer select-none flex items-center justify-between"
      onclick={toggleCurrentlyHacking}
    >
      <div class="text-surface-content text-sm font-medium">
        <div class="flex items-center">
          <div
            class="w-2 h-2 rounded-full bg-green animate-pulse mr-2"
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
                    <Link
                      href={`https://hackclub.slack.com/team/${user.slack_uid}`}
                      target="_blank"
                      class="text-blue hover:underline text-sm"
                    >
                      @{user.display_name || `User ${user.id}`}
                    </Link>
                  {:else}
                    <span class="text-surface-content text-sm"
                      >{user.display_name || `User ${user.id}`}</span
                    >
                  {/if}
                </div>
                {#if user.active_project}
                  <div class="text-xs text-muted ml-8">
                    working on
                    {#if user.active_project.repo_url}
                      <Link
                        href={user.active_project.repo_url}
                        target="_blank"
                        class="text-accent hover:text-cyan transition-colors"
                      >
                        {user.active_project.name}
                      </Link>
                    {:else}
                      {user.active_project.name}
                    {/if}
                    {#if visualizeGitUrl(user.active_project.repo_url)}
                      <Link
                        href={visualizeGitUrl(user.active_project.repo_url)}
                        target="_blank"
                        class="ml-1">🌌</Link
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

      <h3 class="text-2xl font-bold text-surface-content mb-2 text-center w-full">
        Woah hold on a sec
      </h3>
      <p class="text-muted mb-6 text-center w-full">
        You sure you want to log out? You can sign back in later but that is a
        bit of a hassle...
      </p>

      <div class="flex w-full gap-3">
        <div class="flex-1 min-w-0">
          <button
            type="button"
            onclick={closeLogout}
            class="w-full h-10 px-4 rounded-lg transition-colors duration-200 cursor-pointer m-0 bg-dark hover:bg-darkless border border-darkless text-muted"
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
              class="w-full h-10 px-4 rounded-lg transition-colors duration-200 font-medium cursor-pointer m-0 bg-primary hover:bg-primary/75 text-on-primary"
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
