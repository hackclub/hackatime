<script lang="ts">
  const features = [
    {
      title: "Time tracking",
      description:
        "Automatic tracking that starts when you type and stops when you take a break. Down to the second.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />`,
    },
    {
      title: "Language stats",
      description:
        "See your actual tech stack. How much Rust vs. how much time debugging config files.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />`,
    },
    {
      title: "File-level insights",
      description:
        "Drill into specific files. Find the ones consuming all your time.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M9 17v-2m3 2v-4m3 4v-6m2 10H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />`,
    },
    {
      title: "Zero lock-in",
      description:
        "Your data is yours. Export your entire history to JSON or CSV via the REST API.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />`,
    },
    {
      title: "Leaderboards (coming soon)",
      description:
        "Create private leaderboards for your team or hackathon. Compete on consistency.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />`,
    },
    {
      title: "Privacy-first",
      description:
        "We don't sell your data. We don't use it for AI training. Just heartbeats and charts.",
      icon: `<path stroke-linecap="round" stroke-linejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />`,
    },
  ];
</script>

<section class="py-20 w-full" id="features">
  <div class="max-w-[1100px] mx-auto px-6">
    <div class="text-center max-w-[700px] mx-auto mb-12">
      <h2
        class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-4"
      >
        Everything you need, nothing you don't.
      </h2>
      <p class="text-secondary text-lg">
        Granular telemetry for your development environment, delivered via a
        clean dashboard.
      </p>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      {#each features as feature}
        <div class="p-8 bg-surface border border-surface-200 rounded-lg">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="2"
            stroke="currentColor"
            class="w-8 h-8 text-purple mb-4"
          >
            {@html feature.icon}
          </svg>
          <h3 class="text-lg font-semibold text-surface-content mb-2">
            {feature.title}
          </h3>
          <p class="text-secondary text-base leading-relaxed">
            {feature.description}
          </p>
        </div>
      {/each}
    </div>
  </div>
</section>
