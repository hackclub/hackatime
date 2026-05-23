<script lang="ts">
  import Section from "./Section.svelte";

  const cards = [
    {
      title: "No artificial limits",
      body: "Other trackers delete your history after two weeks unless you pay. Hackatime stores it indefinitely, making it a perfect alternative to WakaTime.",
    },
    {
      title: "Community built",
      body: "Built by the makers at Hack Club. Anyone can contribute to the codebase and help shape the product!",
    },
  ];
</script>

<Section id="philosophy" bg="bg-surface">
  <div class="grid grid-cols-1 md:grid-cols-2 gap-16">
    <div>
      <h2
        class="text-3xl md:text-4xl font-semibold text-primary tracking-tight mb-6"
      >
        Your coding data should belong to you.
      </h2>
      <p class="text-secondary text-lg leading-relaxed mb-4">
        Every keystroke and file save tells a story about how you work. Most
        platforms lock your history behind paywalls and opaque privacy policies.
      </p>
      <p class="text-secondary text-lg leading-relaxed">
        <strong class="text-surface-content">Hackatime is different.</strong> We provide
        transparent, community-run infrastructure for tracking your development workflow.
        Your metrics stay accessible, exportable, and free.
      </p>
    </div>
    <div class="space-y-6">
      {#each cards as { title, body }}
        <div class="p-8 bg-darker border border-surface-200 rounded-lg">
          <h3 class="text-lg font-semibold text-surface-content mb-2">
            {title}
          </h3>
          <p class="text-secondary text-base leading-relaxed">{body}</p>
        </div>
      {/each}
    </div>
  </div>
</Section>
