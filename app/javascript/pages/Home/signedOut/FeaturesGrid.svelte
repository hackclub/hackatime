<script lang="ts">
  const features = [
    {
      title: "Time tracking",
      description:
        "Automatic tracking that starts when you type and stops when you take a break. Down to the second.",
      icon: `<path fill-rule="evenodd" clip-rule="evenodd" d="M12 2.25c-5.385 0-9.75 4.365-9.75 9.75s4.365 9.75 9.75 9.75 9.75-4.365 9.75-9.75S17.385 2.25 12 2.25zM12.75 6a.75.75 0 00-1.5 0v6c0 .414.336.75.75.75h4.5a.75.75 0 000-1.5h-3.75V6z" />`,
    },
    {
      title: "Language stats",
      description:
        "See your actual tech stack. How much Rust vs. how much time debugging config files.",
      icon: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-6"><path fill-rule="evenodd" d="M3 6a3 3 0 0 1 3-3h12a3 3 0 0 1 3 3v12a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6Zm14.25 6a.75.75 0 0 1-.22.53l-2.25 2.25a.75.75 0 1 1-1.06-1.06L15.44 12l-1.72-1.72a.75.75 0 1 1 1.06-1.06l2.25 2.25c.141.14.22.331.22.53Zm-10.28-.53a.75.75 0 0 0 0 1.06l2.25 2.25a.75.75 0 1 0 1.06-1.06L8.56 12l1.72-1.72a.75.75 0 1 0-1.06-1.06l-2.25 2.25Z" clip-rule="evenodd" /></svg>`,
    },
    {
      title: "File-level insights",
      description:
        "Drill into specific files. Find the ones consuming all your time.",
      icon: `<path d="M5.625 1.5c-1.036 0-1.875.84-1.875 1.875v17.25c0 1.035.84 1.875 1.875 1.875h12.75c1.035 0 1.875-.84 1.875-1.875V12.75A3.75 3.75 0 0016.5 9h-1.875a1.875 1.875 0 01-1.875-1.875V5.25A3.75 3.75 0 009 1.5H5.625z" /><path d="M12.971 1.816A5.23 5.23 0 0114.25 5.25v1.875c0 .207.168.375.375.375H16.5a5.23 5.23 0 013.434 1.279 9.768 9.768 0 00-6.963-6.963z" /><path d="M9 12.75a.75.75 0 00-1.5 0v4.5a.75.75 0 001.5 0v-4.5zm2.25 2.25a.75.75 0 00-1.5 0v2.25a.75.75 0 001.5 0V15zm2.25-1.5a.75.75 0 00-1.5 0v3.75a.75.75 0 001.5 0v-3.75z" />`,
    },
    {
      title: "Zero lock-in",
      description:
        "Your data is yours. Export your entire history to JSON or CSV via the REST API.",
      icon: `
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="size-6">
        <path fill-rule="evenodd" d="M9.75 6.75h-3a3 3 0 0 0-3 3v7.5a3 3 0 0 0 3 3h7.5a3 3 0 0 0 3-3v-7.5a3 3 0 0 0-3-3h-3V1.5a.75.75 0 0 0-1.5 0v5.25Zm0 0h1.5v5.69l1.72-1.72a.75.75 0 1 1 1.06 1.06l-3 3a.75.75 0 0 1-1.06 0l-3-3a.75.75 0 1 1 1.06-1.06l1.72 1.72V6.75Z" clip-rule="evenodd" />
        <path d="M7.151 21.75a2.999 2.999 0 0 0 2.599 1.5h7.5a3 3 0 0 0 3-3v-7.5c0-1.11-.603-2.08-1.5-2.599v7.099a4.5 4.5 0 0 1-4.5 4.5H7.151Z" />
      </svg>`,
    },
    {
      title: "Leaderboards (coming soon)",
      description:
        "Create private leaderboards for your team or hackathon. Compete on consistency.",
      icon: `<path d="M4.5 6.375a4.125 4.125 0 118.25 0 4.125 4.125 0 01-8.25 0zM14.25 8.625a3.375 3.375 0 116.75 0 3.375 3.375 0 01-6.75 0zM1.5 19.125a7.125 7.125 0 0114.25 0v.003l-.001.119a.75.75 0 01-.363.63 13.067 13.067 0 01-6.761 1.873c-2.472 0-4.786-.684-6.76-1.873a.75.75 0 01-.364-.63l-.001-.122zM17.25 19.128l-.001.144a2.25 2.25 0 01-.233.96 10.088 10.088 0 005.06-1.01.75.75 0 00.42-.643 4.875 4.875 0 00-6.957-4.611 8.586 8.586 0 011.71 5.157v.003z" />`,
    },
    {
      title: "Privacy-first",
      description:
        "We don't sell your data. We don't use it for AI training. Just heartbeats and charts.",
      icon: `<path fill-rule="evenodd" clip-rule="evenodd" d="M12 1.5a5.25 5.25 0 00-5.25 5.25v3a3 3 0 00-3 3v6.75a3 3 0 003 3h10.5a3 3 0 003-3v-6.75a3 3 0 00-3-3v-3c0-2.9-2.35-5.25-5.25-5.25zm3.75 8.25v-3a3.75 3.75 0 10-7.5 0v3h7.5z" />`,
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
      <p class="text-secondary text-lg text-pretty">
        Granular telemetry for your development environment, delivered via a
        clean dashboard.
      </p>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
      {#each features as feature}
        <div class="p-8 bg-surface border border-surface-200 rounded-lg">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            fill="currentColor"
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
