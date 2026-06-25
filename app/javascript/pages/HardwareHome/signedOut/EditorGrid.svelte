<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Section from "./Section.svelte";
  import Plus from "hcicons-svelte/plus";

  const editors = [
    { name: "VS Code", slug: "vs-code" },
    { name: "JetBrains", slug: "intellij-idea" },
    { name: "Vim", slug: "vim" },
    { name: "Neovim", slug: "neovim" },
    { name: "Sublime", slug: "sublime-text" },
    { name: "Cursor", slug: "cursor" },
    { name: "Zed", slug: "zed" },
    { name: "Terminal", slug: "terminal" },
    { name: "Figma", slug: "figma" },
    { name: "Godot", slug: "godot" },
  ];

  const tileBox =
    "w-16 h-16 bg-surface border border-surface-200 rounded-xl flex items-center justify-center mb-2 shadow-sm transition-all duration-150 group-hover:border-primary group-hover:shadow-md group-hover:-translate-y-0.5";
</script>

<Section id="integrations" bg="bg-surface-100">
  <div class="grid md:grid-cols-3 gap-12 items-center">
    <!-- Right 2/3: existing content -->
    <div class="md:col-span-2 text-center">
      <h2
        class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-4"
      >
        Works where you work.
      </h2>
      <p class="text-secondary mx-auto max-w-[60ch] text-lg mb-12">
        Hackatime uses the open-source WakaTime plugin ecosystem. If your editor
        has a plugin, it works with Hackatime.
      </p>
      <div
        class="flex flex-wrap justify-center gap-x-8 gap-y-10 max-w-[800px] mx-auto"
      >
        {#each editors as { name, slug }}
          <Link
            href={`/docs/editors/${slug}`}
            class="flex flex-col items-center w-20 group"
          >
            <div class={tileBox}>
              <img
                src={`/images/editor-icons/${slug}-128.png`}
                alt={name}
                class="w-8 h-8 object-contain transition-transform duration-150 group-hover:scale-110"
              />
            </div>
            <span
              class="text-xs font-medium text-secondary transition-colors group-hover:text-primary"
              >{name}</span
            >
          </Link>
        {/each}

        <Link
          href="/docs#all-editors"
          class="flex flex-col items-center w-20 group"
        >
          <div class={tileBox}>
            <Plus
              size={32}
              class="text-secondary transition-colors group-hover:text-primary"
            />
          </div>
          <span
            class="text-xs font-medium text-secondary transition-colors group-hover:text-primary"
            >More</span
          >
        </Link>
      </div>
    </div>
    <!-- Left 1/3: Lookout callout -->
    <div
      class="flex flex-col items-center text-center md:items-start md:text-left bg-surface border border-surface-200 rounded-2xl p-6 shadow-sm"
    >
      <img
        src="https://lookout.hackclub.com/icon.png"
        alt="Lookout"
        class="w-14 h-14 rounded-xl mb-4 shadow-sm"
      />
      <h3
        class="text-xl font-semibold text-surface-content tracking-tight mb-2"
      >
        CAD?
      </h3>
      <p class="text-secondary text-base max-w-[32ch]">
        Use
        <Link
          href="https://lookout.hackclub.com"
          class="text-primary underline underline-offset-2 hover:opacity-80"
          >Lookout</Link
        >
        to automatically record a timelapse of your session alongside your Hackatime
        stats.
      </p>
    </div>
  </div>
</Section>
