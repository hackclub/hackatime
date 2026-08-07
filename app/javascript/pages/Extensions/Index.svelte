<script lang="ts">
  import Download from "hcicons-svelte/download";

  const EXTENSIONS: {
    name: string;
    source: string;
    description: string;
    install: string;
    buttonLabel?: string;
  }[] = [
    {
      name: "Hackatime Desktop",
      source: "https://github.com/hackclub/hackatime-desktop",
      description:
        "Desktop app for Hackatime. Runs on Mac, Windows, and Linux.",
      install: "https://github.com/hackclub/hackatime-desktop/releases",
    },
    {
      name: "Cattatime",
      source: "https://github.com/joysudo/catatime/tree/master",
      description:
        "A Tamagotchi system. Code, fill your cup, and get your pet rewards.",
      install: "https://github.com/joysudo/catatime/releases/",
    },
    {
      name: "HackaStreak",
      source: "https://github.com/hippogriff101/HackaStreak",
      description: "Check a user's Hackatime streak in Slack.",
      install: "https://hackclub.enterprise.slack.com/archives/C0AJLGZ73NE",
      buttonLabel: "Try it out!",
    },
    {
      name: "Hackabile",
      source: "https://github.com/nilanshsharma23/hackabile",
      description: "Android app for Hackatime.",
      install: "https://github.com/nilanshsharma23/hackabile/releases/tag/v1.0",
    },
  ];
</script>

<svelte:head><title>Extensions - Hackatime</title></svelte:head>

<div>
  <div class="mb-6 sm:mb-8">
    <h1
      class="text-2xl sm:text-3xl font-bold text-surface-content mb-1 sm:mb-2"
    >
      Extensions
    </h1>
    <p class="text-sm sm:text-base text-muted">
      Third-party tools created by the community.
      <span class="text-primary opacity-80 italic text-sm ml-1">
        * Not guaranteed to work.
      </span>
    </p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    {#each EXTENSIONS as ext}
      <div
        class="flex flex-col bg-surface border border-surface-200 rounded-lg p-5 hover:border-surface-300 transition-colors"
      >
        <h2 class="text-xl font-bold text-surface-content mb-1">{ext.name}</h2>
        <p class="text-muted text-sm leading-relaxed mb-6 flex-1">
          {ext.description}
        </p>
        <div class="grid grid-cols-2 gap-3 mt-auto">
          <a
            href={ext.install}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center justify-center gap-2 px-4 py-2 rounded bg-primary text-on-primary font-medium text-sm hover:opacity-90 transition-opacity"
          >
            <span>{ext.buttonLabel ?? "Install"}</span>
            <Download size={16} />
          </a>
          <a
            href={ext.source}
            target="_blank"
            rel="noopener noreferrer"
            class="flex items-center justify-center gap-2 px-4 py-2 rounded bg-surface-200 text-surface-content font-medium text-sm hover:bg-surface-300 transition-colors"
          >
            Source
          </a>
        </div>
      </div>
    {/each}
  </div>
</div>
