<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";

  type HomeStats = { seconds_tracked?: number; users_tracked?: number };

  let {
    hca_auth_path,
    slack_auth_path,
    email_auth_path,
    sign_in_email,
    show_dev_tool,
    dev_magic_link,
    csrf_token,
    home_stats,
  }: {
    hca_auth_path: string;
    slack_auth_path: string;
    email_auth_path: string;
    sign_in_email: boolean;
    show_dev_tool: boolean;
    dev_magic_link?: string | null;
    csrf_token: string;
    home_stats: HomeStats;
  } = $props();

  let isSigningIn = $state(false);

  const editors = [
    { name: "VS Code", slug: "vs-code" },
    { name: "PyCharm", slug: "pycharm" },
    { name: "IntelliJ", slug: "intellij-idea" },
    { name: "Vim", slug: "vim" },
    { name: "Neovim", slug: "neovim" },
    { name: "Zed", slug: "zed" },
    { name: "Cursor", slug: "cursor" },
    { name: "Terminal", slug: "terminal" },
  ];

  const numberFormatter = new Intl.NumberFormat("en-US");
  const pluralize = (count: number, singular: string, plural: string) =>
    count === 1 ? singular : plural;
  const formatNumber = (value: number) => numberFormatter.format(value);

  const hoursTracked = $derived(
    home_stats?.seconds_tracked
      ? Math.floor(home_stats.seconds_tracked / 3600)
      : 0,
  );
  const usersTracked = $derived(home_stats?.users_tracked ?? 0);

  // Grid background pattern
  const gridPattern = `background-image: linear-gradient(to right, #4A2D3133 1px, transparent 1px), linear-gradient(to bottom, #4A2D3133 1px, transparent 1px); background-size: 6rem 6rem;`;
</script>

<div
  class="min-h-screen bg-darker text-white font-sans selection:bg-primary selection:text-white relative overflow-hidden flex flex-col"
>
  <!-- Decorative Grid Background -->
  <div
    class="absolute inset-0 pointer-events-none opacity-60"
    style={gridPattern}
  ></div>

  <!-- Navigation -->
  <nav
    class="relative z-10 w-full max-w-7xl mx-auto px-6 py-6 flex justify-between items-center"
  >
    <div class="flex items-center gap-2 min-w-[140px]">
      <img src="/images/new-icon-rounded.png" class="h-8 w-8" alt="Logo" />
      <span class="font-bold tracking-tight text-lg">Hackatime</span>
    </div>
    <div class="hidden md:flex gap-8 text-sm font-medium text-text-muted">
      <a href="#stats" class="hover:text-white transition-colors">Stats</a>
      <a href="#editors" class="hover:text-white transition-colors">Editors</a>
      <Link href="/docs" class="hover:text-white transition-colors"
        >Developers</Link
      >
    </div>
    <div class="min-w-[140px] flex justify-end">
      <a
        href={hca_auth_path}
        class="text-sm font-bold border border-primary text-primary px-4 py-2 rounded-lg hover:bg-primary hover:text-white transition-all"
      >
        Login
      </a>
    </div>
  </nav>

  <!-- Main Content -->
  <main
    class="relative z-10 flex-1 flex flex-col items-center justify-center w-full max-w-4xl mx-auto px-4 pt-10 pb-20"
  >
    <!-- Hero Text -->
    <div class="text-center mb-10 mt-4 space-y-4">
      <h1 class="text-5xl font-serif tracking-tight leading-[1.1]">
        The free and <br />
        <span class="italic text-primary">open-source</span> coding time tracker.
      </h1>
      <p class="text-secondary max-w-xl mx-auto text-lg leading-relaxed">
        Code stats, straight from your code editors. That's it!
      </p>
    </div>

    <!-- Auth Section -->
    <div class="w-full max-w-md space-y-4">
      {#if sign_in_email}
        <div
          class="bg-dark rounded-2xl border border-darkless p-8 text-center space-y-2"
        >
          <p class="text-white font-medium">Check your email!</p>
          <p class="text-secondary text-sm">
            We sent a sign-in link to your inbox. Check your spam if you can't
            see it!
          </p>
          {#if show_dev_tool && dev_magic_link}
            <a
              href={dev_magic_link}
              class="text-xs text-secondary underline hover:text-white"
              >Dev: Open Link</a
            >
          {/if}
        </div>
      {:else}
        <!-- Primary Auth Buttons -->
        <a
          href={hca_auth_path}
          onclick={() => (isSigningIn = true)}
          class="w-full flex items-center justify-center gap-3 px-6 py-3.5 rounded-xl bg-primary text-white font-medium hover:brightness-110 transition-all"
        >
          {#if isSigningIn}
            <svg class="h-5 w-5 animate-spin" viewBox="0 0 24 24" fill="none"
              ><circle
                class="opacity-25"
                cx="12"
                cy="12"
                r="10"
                stroke="currentColor"
                stroke-width="4"
              ></circle><path
                class="opacity-75"
                fill="currentColor"
                d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
              ></path></svg
            >
          {:else}
            <img
              src="/images/icon-rounded.png"
              class="h-5 w-5"
              alt="Hack Club"
            />
          {/if}
          <span>Sign in with Hack Club</span>
        </a>

        <a
          href={slack_auth_path}
          class="w-full flex items-center justify-center gap-3 px-6 py-3.5 rounded-xl bg-dark border border-darkless text-white font-medium hover:bg-darkless transition-all"
        >
          <svg class="w-5 h-5" viewBox="0 0 24 24" fill="currentColor"
            ><path
              d="M6 15a2 2 0 0 1-2 2a2 2 0 0 1-2-2a2 2 0 0 1 2-2h2zm1 0a2 2 0 0 1 2-2a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2a2 2 0 0 1-2-2zm2-8a2 2 0 0 1-2-2a2 2 0 0 1 2-2a2 2 0 0 1 2 2v2zm0 1a2 2 0 0 1 2 2a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2a2 2 0 0 1 2-2zm8 2a2 2 0 0 1 2-2a2 2 0 0 1 2 2a2 2 0 0 1-2 2h-2zm-1 0a2 2 0 0 1-2 2a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2a2 2 0 0 1 2 2zm-2 8a2 2 0 0 1 2 2a2 2 0 0 1-2 2a2 2 0 0 1-2-2v-2zm0-1a2 2 0 0 1-2-2a2 2 0 0 1 2-2h5a2 2 0 0 1 2 2a2 2 0 0 1-2 2z"
            /></svg
          >
          <span>Sign in with Slack</span>
        </a>

        <!-- Divider -->
        <div class="flex items-center gap-4 py-1">
          <div class="flex-1 h-px bg-darkless"></div>
          <span class="text-xs text-secondary/60 uppercase tracking-wider"
            >or</span
          >
          <div class="flex-1 h-px bg-darkless"></div>
        </div>

        <!-- Email Form -->
        <form method="post" action={email_auth_path} data-turbo="false">
          <input type="hidden" name="authenticity_token" value={csrf_token} />
          <div class="flex gap-2">
            <input
              type="email"
              name="email"
              placeholder="you@email.com"
              required
              class="flex-1 bg-dark text-white placeholder-secondary/40 rounded-xl py-3.5 px-4 focus:outline-none focus:ring-2 focus:ring-primary/50 transition-all border border-darkless focus:border-primary text-sm"
            />
            <Button
              type="submit"
              unstyled
              class="px-5 py-3.5 bg-dark border border-primary text-white rounded-xl hover:bg-primary transition-all text-sm font-medium"
            >
              Send link
            </Button>
          </div>
        </form>
      {/if}
    </div>

    <!-- Stats / Feature Pills -->
    <div class="mt-8 flex flex-wrap justify-center gap-3" id="stats">
      {#if home_stats?.seconds_tracked}
        <div
          class="px-4 py-2 bg-dark border border-darkless rounded-lg shadow-sm"
        >
          <span class="text-sm font-medium text-white"
            >{formatNumber(hoursTracked)} hours tracked</span
          >
        </div>
        <div
          class="px-4 py-2 bg-dark border border-darkless rounded-lg shadow-sm"
        >
          <span class="text-sm font-medium text-white"
            >{formatNumber(usersTracked)} hackers</span
          >
        </div>
      {/if}
      <div
        class="px-4 py-2 bg-dark border border-darkless rounded-lg shadow-sm"
      >
        <span class="text-sm font-medium text-white">Works offline</span>
      </div>
      <div
        class="px-4 py-2 bg-dark border border-darkless rounded-lg shadow-sm"
      >
        <span class="text-sm font-medium text-white">100% free</span>
      </div>
    </div>

    <!-- Editor Logos -->
    <div class="mt-20 text-center w-full" id="editors">
      <h3 class="text-xl font-serif mb-8 text-secondary">
        Compatible with all your favourite editors
      </h3>
      <div
        class="grid grid-cols-4 md:grid-cols-8 gap-8 items-center justify-items-center opacity-60 hover:opacity-100 transition-all duration-500"
      >
        {#each editors as editor}
          <Link
            href={`/docs/editors/${editor.slug}`}
            class="group flex flex-col items-center gap-2 hover:-translate-y-1 transition-transform"
          >
            <img
              src={`/images/editor-icons/${editor.slug}-128.png`}
              alt={editor.name}
              class="w-8 h-8 object-contain"
            />
            <span
              class="text-[10px] uppercase tracking-wider opacity-0 group-hover:opacity-100 transition-opacity absolute -bottom-5 text-secondary"
              >{editor.name}</span
            >
          </Link>
        {/each}
      </div>
      <div class="mt-8 text-sm text-secondary/60">
        + 70 more supported editors
      </div>
    </div>
  </main>
</div>
