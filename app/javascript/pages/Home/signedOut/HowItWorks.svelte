<script lang="ts">
  import Section from "./Section.svelte";

  const steps = [
    {
      n: "01",
      title: "Register",
      body: "Create a free account on Hackatime. You'll get an API key — that's how your editor identifies you.",
    },
    {
      n: "02",
      title: "Install Plugin",
      body: "Install the WakaTime plugin for your editor (VS Code, JetBrains, Vim, etc.) from its extension marketplace.",
    },
  ];
</script>

<Section>
  <h2
    class="text-3xl md:text-4xl font-semibold text-surface-content text-center tracking-tight mb-12"
  >
    Start tracking in 30 seconds.
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
    {#each steps as { n, title, body }}
      <div class="border-l-2 border-surface-200 pl-4">
        <span class="text-sm font-bold text-primary tracking-widest">{n}</span>
        <h3 class="text-lg font-semibold text-surface-content mt-2 mb-2">
          {title}
        </h3>
        <p class="text-secondary text-base leading-relaxed">{body}</p>
      </div>
    {/each}
    <div class="border-l-2 border-surface-200 pl-4">
      <span class="text-sm font-bold text-primary tracking-widest">03</span>
      <h3 class="text-lg font-semibold text-surface-content mt-2 mb-2">
        Configure
      </h3>
      <p class="text-secondary text-base leading-relaxed">
        Enter your API key and set the <code
          class="text-primary bg-surface-100 px-1.5 py-0.5 rounded text-sm"
          >api_url</code
        > to Hackatime. Done.
      </p>
    </div>
  </div>
</Section>
