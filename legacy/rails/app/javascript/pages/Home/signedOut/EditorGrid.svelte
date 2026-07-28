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
    "w-16 h-16 bg-surface border border-surface-200 rounded-xl flex items-center justify-center mb-2";
</script>

<Section id="integrations" bg="bg-surface-100">
  <div class="text-center">
    <h2
      class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-4"
    >
      Works where you work.
    </h2>
    <p class="text-secondary mx-auto max-w-[60ch] text-lg mb-12">
      Hackatime uses the open-source WakaTime plugin ecosystem. If your editor
      has a plugin, it works with Hackatime.
    </p>
    <div class="flex flex-wrap justify-center gap-12 max-w-[800px] mx-auto">
      {#each editors as { name, slug }}
        <Link
          href={`/docs/editors/${slug}`}
          class="flex flex-col items-center w-20"
        >
          <div class={tileBox}>
            <img
              src={`/images/editor-icons/${slug}-128.png`}
              alt={name}
              class="w-8 h-8 object-contain"
            />
          </div>
          <span class="text-xs font-medium text-secondary">{name}</span>
        </Link>
      {/each}
      <a href="/docs#all-editors" class="flex flex-col items-center w-20 group">
        <div class="{tileBox} group-hover:border-primary transition-colors">
          <Plus
            size={32}
            class="text-secondary group-hover:text-primary transition-colors"
          />
        </div>
        <span
          class="text-xs font-medium text-secondary group-hover:text-primary transition-colors"
          >More</span
        >
      </a>
    </div>
  </div>
</Section>
