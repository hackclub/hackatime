<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Stepper from "./Stepper.svelte";

  const editors = [
    {
      id: "vscode",
      name: "VS Code",
      icon: "/images/editor-icons/vs-code-128.png",
    },
    { id: "vim", name: "Vim", icon: "/images/editor-icons/vim-128.png" },
    {
      id: "neovim",
      name: "Neovim",
      icon: "/images/editor-icons/neovim-128.png",
    },
    { id: "emacs", name: "Emacs", icon: "/images/editor-icons/emacs-128.png" },
    {
      id: "jetbrains",
      name: "JetBrains",
      icon: "/images/editor-icons/jetbrains-128.png",
    },
    {
      id: "sublime",
      name: "Sublime",
      icon: "/images/editor-icons/sublime-text-128.png",
    },
    { id: "unity", name: "Unity", icon: "/images/editor-icons/unity-128.png" },
    { id: "godot", name: "Godot", icon: "/images/editor-icons/godot-128.png" },
    { id: "other", name: "Other", icon: null, emoji: "🔧" },
  ];
</script>

<svelte:head>
  <title>Choose your editor - Step 2</title>
</svelte:head>

<div class="min-h-screen text-surface-content pt-8 pb-16">
  <div class="max-w-2xl mx-auto px-4">
    <Stepper currentStep={2} />

    <div class="text-center mb-10">
      <h2 class="text-2xl font-bold mb-2">Choose your editor</h2>
      <p class="text-secondary">
        Select the editor you'll be using. You can set up more later!
      </p>
    </div>

    <div class="grid grid-cols-2 sm:grid-cols-3 gap-4">
      {#each editors as editor}
        <Link
          href={`/my/wakatime_setup/step-3?editor=${editor.id}`}
          class="group flex flex-col items-center justify-center p-6 bg-dark border border-darkless rounded-xl hover:border-primary transition-all duration-200 hover:shadow-lg hover:shadow-primary/10"
        >
          <div
            class="w-16 h-16 mb-4 flex items-center justify-center transition-transform duration-200 group-hover:scale-110"
          >
            {#if editor.icon}
              <img
                src={editor.icon}
                alt={editor.name}
                class="w-12 h-12 object-contain"
              />
            {:else}
              <div class="w-12 h-12 flex items-center justify-center text-3xl">
                {editor.emoji}
              </div>
            {/if}
          </div>
          <span
            class="font-medium text-surface-content group-hover:text-primary transition-colors"
            >{editor.name}</span
          >
        </Link>
      {/each}
    </div>
  </div>
</div>
