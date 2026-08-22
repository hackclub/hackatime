<script lang="ts">
  import Section from "./Section.svelte";

  type Tab = "hardware" | "software";

  let activeTab: Tab = "hardware";

  const steps: Record<Tab, { n: string; title: string; body: string }[]> = {
    software: [
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
      {
        n: "03",
        title: "Configure",
        body: "Enter your API key and set the api_url to Hackatime. Done.",
      },
    ],
    hardware: [
      {
        n: "01",
        title: "Register",
        body: "Create a free account on Hackatime. We'll connect to your program for timelapses.",
      },
      {
        n: "02",
        title: "Install Lookout",
        body: "Install Lookout, our timelapse recording software. It works on Windows, Mac, and Linux.",
      },
      {
        n: "03",
        title: "Configure",
        body: "Start a timelapse from your program's site. Done.",
      },
    ],
  };
</script>

<Section>
  <h2
    class="text-3xl md:text-4xl font-semibold text-surface-content text-center tracking-tight mb-8"
  >
    Start tracking in 30 seconds.
  </h2>

  <div class="flex justify-center mb-12">
    <div class="inline-flex rounded-lg bg-surface-100 p-1">
      <button
        class="px-5 py-2 rounded-md text-sm font-semibold tracking-wide transition-colors"
        class:bg-surface-0={activeTab === "hardware"}
        class:text-primary={activeTab === "hardware"}
        class:text-secondary={activeTab !== "hardware"}
        on:click={() => (activeTab = "hardware")}
      >
        Hardware
      </button>
      <button
        class="px-5 py-2 rounded-md text-sm font-semibold tracking-wide transition-colors"
        class:bg-surface-0={activeTab === "software"}
        class:text-primary={activeTab === "software"}
        class:text-secondary={activeTab !== "software"}
        on:click={() => (activeTab = "software")}
      >
        Software
      </button>
    </div>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
    {#each steps[activeTab] as { n, title, body }}
      <div class="border-l-2 border-surface-200 pl-4">
        <span class="text-sm font-bold text-primary tracking-widest">{n}</span>
        <h3 class="text-lg font-semibold text-surface-content mt-2 mb-2">
          {title}
        </h3>
        <p class="text-secondary text-base leading-relaxed">{body}</p>
      </div>
    {/each}
  </div>
</Section>
