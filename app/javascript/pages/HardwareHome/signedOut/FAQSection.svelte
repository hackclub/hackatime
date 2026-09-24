<script lang="ts">
  import Section from "./Section.svelte";

  const faqs = [
    {
      q: "Is this really free?",
      a: "Yep. Hackatime is a free service by Hack Club. We made it for ourselves and our events, and it's good marketing :)",
    },
    {
      q: "How do I migrate from WakaTime?",
      a: "Point your existing WakaTime plugin at Hackatime's API URL and enter your Hackatime API key! You can even import your WakaTime data into Hackatime.",
    },
    {
      q: "Is my design private?",
      a: "Hackatime only receives metadata (e.g. file names, project names, timestamps, language). We never see your actual source code.",
    },
    {
      q: "Can I self-host this?",
      a: "Yep! The entire codebase is open source on GitHub. Spin up your own instance for complete data sovereignty.",
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
