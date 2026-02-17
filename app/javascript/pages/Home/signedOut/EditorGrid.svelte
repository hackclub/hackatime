<script lang="ts">
  import { Link } from "@inertiajs/svelte";

  const editors = [
    { name: "VS Code", slug: "vs-code" },
    { name: "JetBrains", slug: "intellij-idea" },
    { name: "Vim", slug: "vim" },
    { name: "Neovim", slug: "neovim" },
    { name: "Sublime", slug: "sublime-text" },
    { name: "Cursor", slug: "cursor" },
    { name: "Zed", slug: "zed" },
    { name: "Terminal", slug: "terminal" },
  ];
</script>

<section class="py-20 w-full bg-surface-100" id="integrations">
  <div class="max-w-[1100px] mx-auto px-6 text-center">
    <h2 class="text-3xl md:text-4xl font-semibold text-surface-content tracking-tight mb-4">Works where you work.</h2>
    <p class="text-secondary mx-auto max-w-[60ch] text-lg mb-12">
      Hackatime uses the open-source WakaTime plugin ecosystem.
      If your editor has a plugin, it works with Hackatime.
    </p>
    <div class="flex flex-wrap justify-center gap-12 max-w-[800px] mx-auto">
      {#each editors as editor}
        <Link href={`/docs/editors/${editor.slug}`} class="flex flex-col items-center w-20">
          <div class="w-16 h-16 bg-surface border border-surface-200 rounded-xl flex items-center justify-center mb-2">
            <img
              src={`/images/editor-icons/${editor.slug}-128.png`}
              alt={editor.name}
              class="w-8 h-8 object-contain"
            />
          </div>
          <span class="text-xs font-medium text-secondary">{editor.name}</span>
        </Link>
      {/each}
    </div>
  </div>
</section>
