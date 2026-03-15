<script lang="ts">
  import { onMount } from "svelte";
  import type { SettingsSubsection } from "../types";

  let { items = [] }: { items?: SettingsSubsection[] } = $props();

  let activeHash = $state("");

  const normalizedHash = (value: string) => value.replace(/^#/, "");

  const updateActiveHash = () => {
    if (typeof window === "undefined") return;
    activeHash = normalizedHash(window.location.hash);
  };

  const scrollToItem = (event: MouseEvent, id: string) => {
    if (typeof window === "undefined" || typeof document === "undefined")
      return;

    const target = document.getElementById(id);
    if (!target) return;

    event.preventDefault();
    activeHash = id;
    target.scrollIntoView({ behavior: "smooth", block: "start" });
    window.history.replaceState(null, "", `#${id}`);
  };

  const isActive = (id: string) => {
    if (!activeHash) return items[0]?.id === id;
    return activeHash === id;
  };

  onMount(() => {
    updateActiveHash();
    window.addEventListener("hashchange", updateActiveHash);
    return () => window.removeEventListener("hashchange", updateActiveHash);
  });
</script>

{#if items.length > 0}
  <nav
    data-settings-subnav
    aria-label="Settings subsections"
    class="overflow-x-auto pb-1"
  >
    <div class="flex min-w-full items-center gap-2">
      {#each items as item}
        <a
          href={`#${item.id}`}
          data-settings-subnav-item
          data-active={isActive(item.id)}
          onclick={(event) => scrollToItem(event, item.id)}
          class={`inline-flex shrink-0 items-center rounded-full border px-3 py-1.5 text-sm font-medium transition-colors ${
            isActive(item.id)
              ? "border-surface-300 bg-surface-100 text-surface-content"
              : "border-surface-200 bg-surface/70 text-muted hover:border-surface-300 hover:text-surface-content"
          }`}
        >
          {item.label}
        </a>
      {/each}
    </div>
  </nav>
{/if}
