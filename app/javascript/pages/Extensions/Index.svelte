<script lang="ts">
  const EXTENSIONS = [
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
  ];
</script>

<div class="max-w-4xl mx-auto">
  <div class="mb-8">
    <h1 class="text-3xl font-bold text-surface-content mb-2">Extensions</h1>
    <p class="text-muted">
      Third-party tools created by the community.
      <span class="text-primary opacity-80 italic text-sm ml-1">
        * Not guaranteed to work.
      </span>
    </p>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    {#each EXTENSIONS as extension}
      <div
        class="flex flex-col bg-surface border border-surface-200 rounded-lg p-5 hover:border-surface-300 transition-colors"
      >
        <div class="flex justify-between items-start mb-1">
          <h2 class="text-xl font-bold text-surface-content">
            {extension.name}
          </h2>
        </div>

        <p class="text-muted text-sm leading-relaxed mb-6 flex-1">
          {extension.description}
        </p>

        <div class="grid grid-cols-2 gap-3 mt-auto">
          <a
            href={extension.install}
            target="_blank"
            class="flex items-center justify-center gap-2 px-4 py-2 rounded bg-primary text-white font-medium text-sm hover:opacity-90 transition-opacity"
          >
            <span>Install</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="16"
              height="16"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              ><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" /><polyline
                points="7 10 12 15 17 10"
              /><line x1="12" x2="12" y1="15" y2="3" /></svg
            >
          </a>

          <a
            href={extension.source}
            target="_blank"
            class="flex items-center justify-center gap-2 px-4 py-2 rounded bg-surface-200 text-surface-content font-medium text-sm hover:bg-surface-300 transition-colors"
          >
            Source
          </a>
        </div>
      </div>
    {/each}
  </div>
</div>
