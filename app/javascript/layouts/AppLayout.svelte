<script lang="ts">
  import { usePoll } from "@inertiajs/svelte";
  import { untrack } from "svelte";
  import CurrentlyHackingPanel from "../components/CurrentlyHackingPanel.svelte";
  import FlashMessages from "./app/FlashMessages.svelte";
  import Sidebar from "./app/Sidebar.svelte";
  import Footer from "./app/Footer.svelte";
  import LogoutModal from "./app/LogoutModal.svelte";
  import type { Snippet } from "svelte";
  import { onMount, onDestroy } from "svelte";
  import type { LayoutProps } from "../types";

  let { layout, children }: { layout: LayoutProps; children?: Snippet } =
    $props();

  const isBrowser =
    typeof window !== "undefined" && typeof document !== "undefined";

  let navOpen = $state(false);
  let logoutOpen = $state(false);

  const showSidebar = $derived(layout.nav.user_present && !layout.hide_sidebar);

  usePoll(
    untrack(() => layout.currently_hacking?.interval || 30000),
    { only: ["currently_hacking"] },
  );

  const handleResize = () => {
    if (isBrowser && window.innerWidth > 1024) navOpen = false;
  };

  const handleKeydown = (e: KeyboardEvent) => {
    if (e.key === "Escape") {
      navOpen = false;
      logoutOpen = false;
    }
  };

  $effect(() => {
    if (isBrowser) document.body.classList.toggle("overflow-hidden", navOpen);
  });

  $effect(() => {
    if (!isBrowser) return;
    document.documentElement.dataset.theme = layout.theme.name;
    document.documentElement.dataset.colorScheme = layout.theme.color_scheme;
    document
      .querySelector('meta[name="color-scheme"]')
      ?.setAttribute("content", layout.theme.color_scheme);
    document
      .querySelector('meta[name="theme-color"]')
      ?.setAttribute("content", layout.theme.theme_color);
  });

  onMount(() => {
    if (!isBrowser) return;
    handleResize();
    window.addEventListener("resize", handleResize);
    document.addEventListener("keydown", handleKeydown);
  });

  onDestroy(() => {
    if (!isBrowser) return;
    window.removeEventListener("resize", handleResize);
    document.removeEventListener("keydown", handleKeydown);
  });
</script>

<FlashMessages flash={layout.nav.flash} />

{#if showSidebar}
  <Sidebar
    nav={layout.nav}
    {navOpen}
    onToggle={() => (navOpen = !navOpen)}
    onClose={() => (navOpen = false)}
    onLogout={() => (logoutOpen = true)}
  />
{/if}

<main
  class={`min-h-screen min-w-0 flex-1 transition-[margin] duration-300 ease-in-out ${showSidebar ? "lg:ml-62.5" : ""}`}
>
  <div class="mx-auto w-full min-w-0 max-w-7xl p-4 pt-16 md:p-8 lg:pt-8">
    {@render children?.()}

    {#if !layout.hide_footer}
      <Footer
        footer={layout.footer}
        showStopImpersonating={layout.show_stop_impersonating}
      />
    {/if}
  </div>
</main>

{#if layout.currently_hacking}
  <CurrentlyHackingPanel currentlyHacking={layout.currently_hacking} />
{/if}

<LogoutModal bind:open={logoutOpen} csrfToken={layout.csrf_token} />

<style>
  :global(#app) {
    display: flex;
    flex: 1 1 auto;
    min-height: 100vh;
    width: 100%;
  }
</style>
