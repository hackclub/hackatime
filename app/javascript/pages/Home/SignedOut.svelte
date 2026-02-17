<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import PhilosophySection from "./signedOut/PhilosophySection.svelte";
  import FeaturesGrid from "./signedOut/FeaturesGrid.svelte";
  import EditorGrid from "./signedOut/EditorGrid.svelte";
  import HowItWorks from "./signedOut/HowItWorks.svelte";
  import FAQSection from "./signedOut/FAQSection.svelte";
  import CTASection from "./signedOut/CTASection.svelte";

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

  let previousTheme = $state<string | null>(null);

  $effect(() => {
    const html = document.documentElement;
    previousTheme = html.getAttribute("data-theme");
    html.setAttribute("data-theme", "gruvbox_dark");

    const colorSchemeMeta = document.querySelector("meta[name='color-scheme']");
    colorSchemeMeta?.setAttribute("content", "dark");

    return () => {
      if (previousTheme) {
        html.setAttribute("data-theme", previousTheme);
      }
    };
  });

  const numberFormatter = new Intl.NumberFormat("en-US");
  const formatNumber = (value: number) => numberFormatter.format(value);
  const hoursTracked = $derived(
    home_stats?.seconds_tracked
      ? Math.floor(home_stats.seconds_tracked / 3600)
      : 0,
  );
  const usersTracked = $derived(home_stats?.users_tracked ?? 0);
</script>

<div class="landing-page min-h-screen w-full bg-darker text-surface-content">
  <!-- Fixed Header -->
  <header
    class="fixed top-0 w-full bg-darker/95 backdrop-blur-sm z-50 border-b border-surface-200/60"
  >
    <div
      class="max-w-[1100px] mx-auto px-6 py-4 flex justify-between items-center"
    >
      <a href="/" class="flex items-center gap-3">
        <img
          src="/images/new-icon-rounded.png"
          class="w-10 h-10 rounded-lg"
          alt="Hackatime"
        />
        <span class="font-bold text-2xl tracking-tight">Hackatime</span>
      </a>
      <nav
        class="hidden md:flex gap-8 items-center text-sm font-medium text-secondary"
      >
        <a
          href="#philosophy"
          class="hover:text-surface-content transition-colors">Philosophy</a
        >
        <a href="#features" class="hover:text-surface-content transition-colors"
          >Features</a
        >
        <a
          href="#integrations"
          class="hover:text-surface-content transition-colors">Integrations</a
        >
        <a href="#faq" class="hover:text-surface-content transition-colors"
          >FAQ</a
        >
        <a
          href="https://github.com/hackclub/hackatime"
          target="_blank"
          class="hover:text-surface-content transition-colors">GitHub</a
        >
        <Link
          href="/signin"
          class="px-4 py-2 bg-primary text-on-primary rounded-md font-semibold hover:opacity-90 transition-colors"
        >
          Start tracking
        </Link>
      </nav>
    </div>
  </header>

  <section class="pt-40 pb-20">
    <div class="max-w-[900px] mx-auto px-6 text-center">
      <h1
        class="text-5xl md:text-6xl font-bold tracking-tight leading-[1.1] mb-6"
      >
        Track your coding time, for free.
      </h1>
      <p
        class="text-lg md:text-xl text-secondary max-w-[70ch] mx-auto leading-relaxed mb-8"
      >
        Hackatime is a free, open-source replacement for WakaTime. Your coding
        habits, project breakdowns and language stats belong to you - not a
        proprietary database!
      </p>
      <div class="flex flex-col sm:flex-row gap-4 justify-center mb-10">
        <Link
          href="/signin"
          class="px-7 py-3.5 bg-primary text-on-primary rounded-md font-semibold text-base hover:opacity-90 transition-colors"
        >
          Start tracking
        </Link>
        <Link
          href="/docs"
          class="px-7 py-3.5 bg-surface border border-surface-200 text-surface-content rounded-md font-semibold text-base hover:border-primary hover:text-primary transition-colors"
        >
          Read the docs
        </Link>
      </div>

      {#if hoursTracked > 0 || usersTracked > 0}
        <div
          class="flex items-center justify-center gap-8 mb-16 text-secondary text-sm"
        >
          {#if usersTracked > 0}
            <div class="flex flex-col items-center">
              <span class="text-2xl font-bold text-surface-content"
                >{formatNumber(usersTracked)}</span
              >
              <span>users</span>
            </div>
          {/if}
          {#if hoursTracked > 0}
            <div class="flex flex-col items-center">
              <span class="text-2xl font-bold text-surface-content"
                >{formatNumber(hoursTracked)}</span
              >
              <span>hours tracked</span>
            </div>
          {/if}
        </div>
      {:else}
        <div class="mb-16"></div>
      {/if}

      <!-- Browser Mockup -->
      <div
        class="bg-surface border border-surface-200 rounded-lg shadow-lg overflow-hidden"
      >
        <div
          class="bg-surface-100 px-4 py-3 border-b border-surface-200 flex gap-2"
        >
          <div class="w-2.5 h-2.5 rounded-full bg-primary"></div>
          <div class="w-2.5 h-2.5 rounded-full bg-orange"></div>
          <div class="w-2.5 h-2.5 rounded-full bg-cyan"></div>
        </div>
        <div class="bg-surface">
          <img
            src="/images/docs-index.png"
            alt="Hackatime Dashboard"
            class="w-full h-auto block rounded"
          />
        </div>
      </div>
    </div>
  </section>

  <PhilosophySection />
  <FeaturesGrid />
  <EditorGrid />
  <HowItWorks />
  <FAQSection />
  <CTASection
    hoursTracked={formatNumber(hoursTracked)}
    usersTracked={formatNumber(usersTracked)}
  />

  <footer class="py-16 w-full bg-surface">
    <div class="max-w-275 mx-auto px-6">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
        <div class="md:col-span-1">
          <a href="/" class="flex items-center gap-2 mb-4">
            <img
              src="/images/new-icon-rounded.png"
              class="w-8 h-8 rounded-lg"
              alt="Hackatime"
            />
            <span class="font-bold text-xl tracking-tight">Hackatime</span>
          </a>
          <p class="text-sm text-secondary max-w-[35ch] leading-relaxed">
            A project by Hack Club. We build tools, community, and events for
            the next generation of hackers.
          </p>
        </div>
        <div>
          <h5
            class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
          >
            Platform
          </h5>
          <div class="space-y-3">
            <Link
              href="/docs"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Documentation</Link
            >
            <a
              href="/leaderboards"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Leaderboards</a
            >
            <Link
              href="/docs/editors/vs-code"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Editor Setup</Link
            >
          </div>
        </div>
        <div>
          <h5
            class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
          >
            Community
          </h5>
          <div class="space-y-3">
            <a
              href="https://hackclub.com/slack"
              target="_blank"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Slack</a
            >
            <a
              href="https://github.com/hackclub/hackatime"
              target="_blank"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >GitHub</a
            >
            <a
              href="https://hackclub.com"
              target="_blank"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Hack Club</a
            >
          </div>
        </div>
        <div>
          <h5
            class="text-xs uppercase tracking-wider text-muted font-semibold mb-4"
          >
            Legal
          </h5>
          <div class="space-y-3">
            <a
              href="https://hackclub.com/privacy-and-terms"
              target="_blank"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Privacy & Terms</a
            >
            <a
              href="https://hackclub.com/conduct"
              target="_blank"
              class="block text-sm text-secondary hover:text-primary transition-colors"
              >Code of Conduct</a
            >
          </div>
        </div>
      </div>
    </div>
  </footer>
</div>
