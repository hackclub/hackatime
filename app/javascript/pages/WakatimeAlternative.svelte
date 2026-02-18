<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import MarketingFooter from "../components/MarketingFooter.svelte";

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

  type Feature = {
    name: string;
    hackatime: string;
    hackatimeHighlight: boolean;
    wakatimeFree: string;
    wakatimePro: string;
  };

  const features: Feature[] = [
    {
      name: "Price",
      hackatime: "Free forever",
      hackatimeHighlight: true,
      wakatimeFree: "Free",
      wakatimePro: "$9/month",
    },
    {
      name: "Open Source",
      hackatime: "\u2713",
      hackatimeHighlight: true,
      wakatimeFree: "\u2717",
      wakatimePro: "\u2717",
    },
    {
      name: "Editor Support",
      hackatime: "70+ editors",
      hackatimeHighlight: false,
      wakatimeFree: "70+ editors",
      wakatimePro: "70+ editors",
    },
    {
      name: "Data Retention",
      hackatime: "Unlimited",
      hackatimeHighlight: true,
      wakatimeFree: "14 days",
      wakatimePro: "Unlimited",
    },
    {
      name: "Project Stats",
      hackatime: "Full access",
      hackatimeHighlight: true,
      wakatimeFree: "Limited",
      wakatimePro: "Full access",
    },
    {
      name: "Language Breakdown",
      hackatime: "\u2713",
      hackatimeHighlight: true,
      wakatimeFree: "\u2713",
      wakatimePro: "\u2713",
    },
    {
      name: "Leaderboards",
      hackatime: "\u2713 (Community)",
      hackatimeHighlight: true,
      wakatimeFree: "\u2713 (Community)",
      wakatimePro: "\u2713",
    },
    {
      name: "Self-Hosting",
      hackatime: "\u2713",
      hackatimeHighlight: true,
      wakatimeFree: "\u2717",
      wakatimePro: "\u2717",
    },
    {
      name: "Team Features",
      hackatime: "\u2717",
      hackatimeHighlight: false,
      wakatimeFree: "\u2717",
      wakatimePro: "\u2713",
    },
    {
      name: "API Access",
      hackatime: "\u2713 Full",
      hackatimeHighlight: true,
      wakatimeFree: "Limited",
      wakatimePro: "\u2713 Full",
    },
  ];

  type TradeOff = { title: string; description: string };

  const tradeOffs: TradeOff[] = [
    {
      title: "No team dashboards",
      description:
        "WakaTime Pro offers team analytics. Hackatime is focused on individual developers. If you need team insights, WakaTime might be better suited.",
    },
    {
      title: "Community-focused",
      description:
        "Hackatime is built for the Hack Club community. While anyone can use it, some features (like leaderboards) are community-centric.",
    },
    {
      title: "Newer platform",
      description:
        "WakaTime has been around since 2013 and has a mature ecosystem. Hackatime launched in 2024 and is actively developed.",
    },
    {
      title: "No email summaries",
      description:
        "WakaTime sends weekly email reports. Hackatime doesn't currently offer email digests, but this is a feature we're actively working on.",
    },
  ];

  const benefits = [
    "100% free, forever\u2014every feature, no exceptions",
    "Works with all WakaTime plugins\u2014just change your API endpoint",
    "Open source\u2014audit the code, contribute, or self-host",
    "Privacy-first\u2014only metadata tracked, never your code",
    "Community leaderboards\u2014see how you stack up against peers",
  ];
</script>

<div class="min-h-screen w-full bg-darker text-surface-content">
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
          href="/#philosophy"
          class="hover:text-surface-content transition-colors">Philosophy</a
        >
        <a
          href="/#features"
          class="hover:text-surface-content transition-colors">Features</a
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

  <!-- Hero Section -->
  <section class="pt-32 pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h1
        class="text-4xl md:text-5xl font-bold tracking-tight leading-[1.15] mb-6"
      >
        WakaTime Alternative: Free & Open Source Coding Time Tracker
      </h1>
      <p class="text-lg md:text-xl text-secondary leading-relaxed max-w-[75ch]">
        Looking for a WakaTime alternative? <strong class="text-surface-content"
          >Hackatime</strong
        >
        is a free, open source coding time tracker that gives you all the features
        you need, without the paywall. Built by
        <a
          href="https://hackclub.com"
          class="text-primary hover:underline"
          target="_blank">Hack Club</a
        >, it's designed for developers who want powerful analytics without
        monthly fees.
      </p>
    </div>
  </section>

  <!-- Why Look Section -->
  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">
        Why look for a WakaTime alternative?
      </h2>
      <p class="text-secondary leading-relaxed mb-4 max-w-[75ch]">
        WakaTime pioneered automatic coding time tracking, and it's a great
        product - in fact, we even use the same editor extensions! At the same
        time though, its free tier is pretty limited. You get basic stats, but
        advanced features like detailed project breakdowns and longer data
        retention require a paid subscription starting at $9/month ($14/month
        for dashboard history longer than two weeks). For students, hobbyists,
        and open source contributors, that adds up.
      </p>
      <p class="text-secondary leading-relaxed max-w-[75ch]">
        That's where Hackatime comes in. It's built from the ground up to be
        <strong class="text-surface-content">completely free</strong> - no freemium
        model, no premium tiers, no feature gates.
      </p>
    </div>
  </section>

  <!-- Feature Comparison -->
  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-6">
        So, how does Hackatime stack up?
      </h2>
      <div class="overflow-x-auto rounded-lg border border-surface-200/60">
        <table class="w-full border-collapse">
          <thead>
            <tr class="bg-surface/50">
              <th
                class="text-left py-3.5 px-5 text-surface-content font-semibold text-sm"
                >Feature</th
              >
              <th
                class="text-left py-3.5 px-5 text-primary font-semibold text-sm"
                >Hackatime</th
              >
              <th
                class="text-left py-3.5 px-5 text-secondary font-semibold text-sm"
                >WakaTime Free</th
              >
              <th
                class="text-left py-3.5 px-5 text-secondary font-semibold text-sm"
                >WakaTime Pro</th
              >
            </tr>
          </thead>
          <tbody>
            {#each features as feature, i}
              <tr
                class="border-t border-surface-200/40 {i % 2 === 0
                  ? 'bg-surface/20'
                  : ''}"
              >
                <td class="py-3 px-5 text-sm text-surface-content font-medium"
                  >{feature.name}</td
                >
                <td
                  class="py-3 px-5 text-sm {feature.hackatimeHighlight
                    ? 'text-primary font-medium'
                    : 'text-secondary'}">{feature.hackatime}</td
                >
                <td class="py-3 px-5 text-sm text-secondary"
                  >{feature.wakatimeFree}</td
                >
                <td class="py-3 px-5 text-sm text-secondary"
                  >{feature.wakatimePro}</td
                >
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    </div>
  </section>

  <!-- Honest Trade-offs -->
  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">Honest trade-offs</h2>
      <p class="text-secondary leading-relaxed mb-6">
        We believe in transparency. Here's what you should know before
        switching:
      </p>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        {#each tradeOffs as tradeOff}
          <div
            class="p-5 rounded-lg border border-surface-200/40 bg-surface/20"
          >
            <h3 class="text-surface-content font-semibold mb-2">
              {tradeOff.title}
            </h3>
            <p class="text-secondary text-sm leading-relaxed">
              {tradeOff.description}
            </p>
          </div>
        {/each}
      </div>
    </div>
  </section>

  <!-- Why Hackatime -->
  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">
        Why Hackatime might be right for you
      </h2>
      <p class="text-secondary leading-relaxed mb-6">
        If you're a student, open source contributor, or developer who wants
        powerful coding analytics without paying a subscription, Hackatime
        delivers:
      </p>
      <ul class="space-y-3">
        {#each benefits as benefit}
          <li class="flex items-start gap-3">
            <span class="text-primary mt-0.5 flex-shrink-0">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="18"
                height="18"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              >
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </span>
            <span class="text-secondary leading-relaxed">{benefit}</span>
          </li>
        {/each}
      </ul>
    </div>
  </section>

  <!-- Getting Started -->
  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">Getting started</h2>
      <p class="text-secondary leading-relaxed mb-6">
        Switching from WakaTime takes less than 5 minutes. Since Hackatime uses
        the same plugin ecosystem, you just update your <code
          class="bg-surface px-2 py-1 rounded text-surface-content text-sm"
          >~/.wakatime.cfg</code
        > file:
      </p>
      <pre
        class="bg-surface border border-surface-200/40 p-5 rounded-lg overflow-x-auto text-sm text-surface-content mb-6 leading-relaxed"><code
          >[settings]
api_url = https://hackatime.hackclub.com/api/hackatime/v1
api_key = YOUR_API_KEY_HERE</code
        ></pre>
      <p class="text-secondary leading-relaxed">
        Or use our <Link
          href="/my/wakatime_setup"
          class="text-primary hover:underline">automated setup page</Link
        > that handles everything for you (sign in first!)
      </p>
    </div>
  </section>

  <!-- CTA -->
  <section class="pb-20">
    <div class="max-w-[900px] mx-auto px-6">
      <div
        class="rounded-xl border border-surface-200/60 bg-surface/30 p-8 md:p-12 text-center"
      >
        <h2 class="text-2xl md:text-3xl font-bold mb-4">Ready to switch?</h2>
        <p class="text-secondary mb-8 max-w-[50ch] mx-auto">
          Join thousands of developers who track their coding time for free. No
          credit card required.
        </p>
        <Link
          href="/signin"
          class="inline-block px-8 py-3.5 bg-primary text-on-primary rounded-md font-semibold text-base hover:opacity-90 transition-colors"
        >
          Start tracking for free
        </Link>
        <p class="text-secondary text-sm mt-4">Takes 2 minutes to set up.</p>
      </div>
    </div>
  </section>

  <MarketingFooter />
</div>
