<script lang="ts">
  import Section from "./Section.svelte";

  const faqs = [
    {
      q: "Is this really free?",
      a: "Yes. Hackatime is a free service by Hack Club. No paid tiers, no premium features, no hidden subscriptions.",
    },
    {
      q: "How do I migrate from WakaTime?",
      a: "Point your existing WakaTime plugin at Hackatime's API URL and enter your Hackatime API key. Both use compatible data formats.",
    },
    {
      q: "Is my code private?",
      a: "Hackatime only receives metadata — file names, project names, timestamps, language. We never see your actual source code.",
    },
    {
      q: "Can I self-host this?",
      a: "Yes. The entire codebase is open source on GitHub. Spin up your own instance for complete data sovereignty.",
    },
  ];
</script>

<Section id="faq" bg="bg-surface">
  <h2
    class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-8"
  >
    Frequently Asked Questions
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-x-8 gap-y-10">
    {#each faqs as { q, a }}
      <div>
        <h4 class="text-lg font-semibold text-surface-content mb-2">{q}</h4>
        <p class="text-secondary text-base leading-relaxed">{a}</p>
      </div>
    {/each}
  </div>
</Section>
