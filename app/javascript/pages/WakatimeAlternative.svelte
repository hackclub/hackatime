<script module lang="ts">
  import MarketingLayout from "../layouts/MarketingLayout.svelte";
  export const layout = MarketingLayout;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import MarketingFooter from "../components/MarketingFooter.svelte";
  import Checkmark from "hcicons-svelte/checkmark";

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
      hackatime: "✓",
      hackatimeHighlight: true,
      wakatimeFree: "✗",
      wakatimePro: "✗",
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
      hackatime: "✓",
      hackatimeHighlight: true,
      wakatimeFree: "✓",
      wakatimePro: "✓",
    },
    {
      name: "Leaderboards",
      hackatime: "✓ (Community)",
      hackatimeHighlight: true,
      wakatimeFree: "✓ (Community)",
      wakatimePro: "✓",
    },
    {
      name: "Self-Hosting",
      hackatime: "✓",
      hackatimeHighlight: true,
      wakatimeFree: "✗",
      wakatimePro: "✗",
    },
    {
      name: "Team Features",
      hackatime: "✗",
      hackatimeHighlight: false,
      wakatimeFree: "✗",
      wakatimePro: "✓",
    },
    {
      name: "API Access",
      hackatime: "✓ Full",
      hackatimeHighlight: true,
      wakatimeFree: "Limited",
      wakatimePro: "✓ Full",
    },
  ];

  const tradeOffs = [
    {
      title: "No team dashboards",
      description:
        "WakaTime Pro has team analytics. We don't. If you need to see what your coworkers are shipping, stick with WakaTime.",
    },
    {
      title: "Built for Hack Club",
      description:
        "Anyone can sign up, but the leaderboards and culture skew toward the Hack Club community. That's a feature for some people and a downside for others.",
    },
    {
      title: "Younger project",
      description:
        "WakaTime has been around since 2013. Hackatime launched in 2024. The plugin ecosystem is the same, but we're still adding things.",
    },
  ];

  const benefits = [
    "Free, forever. No paid tier hiding behind a feature gate.",
    "Works with every WakaTime plugin. You just point it at a different URL.",
    "Open source, so you can read the code, send a PR, or run your own copy.",
    "We only track metadata (file names, languages, time). Never your code.",
    "Leaderboards if you want to see how you stack up against other people.",
  ];

  const navLinks = [
    { href: "/#philosophy", label: "Philosophy", external: false },
    { href: "/#features", label: "Features", external: false },
    {
      href: "https://github.com/hackclub/hackatime",
      label: "GitHub",
      external: true,
    },
  ];
</script>

<svelte:head>
  <title>Wakatime vs Hackatime</title>
</svelte:head>

<div class="min-h-screen w-full bg-darker text-surface-content">
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
        {#each navLinks as link}
          <a
            href={link.href}
            target={link.external ? "_blank" : undefined}
            class="hover:text-surface-content transition-colors">{link.label}</a
          >
        {/each}
        <Link
          href="/signin"
          class="px-4 py-2 bg-primary text-on-primary rounded-md font-semibold hover:opacity-90 transition-colors"
        >
          Start tracking
        </Link>
      </nav>
    </div>
  </header>

  <section class="pt-32 pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h1
        class="text-4xl md:text-5xl font-bold tracking-tight leading-[1.15] mb-6"
      >
        WakaTime vs Hackatime
      </h1>
      <p class="text-lg md:text-xl text-secondary leading-relaxed max-w-[75ch]">
        Want to track your coding time without paying $9 a month?
        <strong class="text-surface-content">Hackatime</strong> is a free, open
        source tracker built by
        <a
          href="https://hackclub.com"
          class="text-primary hover:underline"
          target="_blank">Hack Club</a
        >. It uses the same editor plugins as WakaTime, so switching is mostly a
        config change.
      </p>
    </div>
  </section>

  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">
        Why look for a WakaTime alternative?
      </h2>
      <p class="text-secondary leading-relaxed mb-4 max-w-[75ch]">
        WakaTime invented this category and the product is genuinely good. We
        like it enough that we use their editor extensions. The catch is the
        free tier: you get basic stats, but project breakdowns and history past
        two weeks live behind a $9/month plan (or $14/month if you want more
        than two weeks of dashboard history). If you're a student or just
        tracking personal projects, paying every month for what's basically a
        nice graph gets old.
      </p>
      <p class="text-secondary leading-relaxed max-w-[75ch]">
        Hackatime is <strong class="text-surface-content">free</strong>. Not
        free trial, not free tier - just free. We're not planning to add a paid
        version later either.
      </p>
    </div>
  </section>

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

  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">What you give up</h2>
      <p class="text-secondary leading-relaxed mb-6">
        A few things WakaTime does that we don't:
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

  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">
        Reasons you might prefer Hackatime
      </h2>
      <p class="text-secondary leading-relaxed mb-6">
        Especially if you're a student, an open source contributor, or just not
        thrilled about another monthly subscription:
      </p>
      <ul class="space-y-3">
        {#each benefits as benefit}
          <li class="flex items-start gap-3">
            <span class="text-primary mt-0.5 flex-shrink-0">
              <Checkmark size={18} />
            </span>
            <span class="text-secondary leading-relaxed">{benefit}</span>
          </li>
        {/each}
      </ul>
    </div>
  </section>

  <section class="pb-16">
    <div class="max-w-[900px] mx-auto px-6">
      <h2 class="text-2xl md:text-3xl font-semibold mb-5">Getting started</h2>
      <p class="text-secondary leading-relaxed mb-6">
        Switching takes a couple of minutes. Same plugins, different server -
        edit your
        <code class="bg-surface px-2 py-1 rounded text-surface-content text-sm"
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
        Or sign in and let our <Link
          href="/setup"
          class="text-primary hover:underline">setup page</Link
        > do it for you.
      </p>
    </div>
  </section>

  <section class="pb-20">
    <div class="max-w-[900px] mx-auto px-6">
      <div
        class="rounded-xl border border-surface-200/60 bg-surface/30 p-8 md:p-12 text-center"
      >
        <h2 class="text-2xl md:text-3xl font-bold mb-4">Give it a try!</h2>
        <p class="text-secondary mb-8 max-w-[50ch] mx-auto">
          Install the plugin and see your hours.
        </p>
        <Link
          href="/signin"
          class="inline-block px-8 py-3.5 bg-primary text-on-primary rounded-md font-semibold text-base hover:opacity-90 transition-colors"
        >
          Start tracking for free
        </Link>
        <p class="text-secondary text-sm mt-4">Setup takes about 2 minutes.</p>
      </div>
    </div>
  </section>

  <MarketingFooter />
</div>
