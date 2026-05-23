<script lang="ts">
  import { onMount } from "svelte";
  import type { SettingsSubsection } from "../types";

  let { items = [] }: { items?: SettingsSubsection[] } = $props();

  let activeHash = $state("");

  const updateActiveHash = () => {
    if (typeof window !== "undefined")
      activeHash = window.location.hash.replace(/^#/, "");
  };

  const isActive = (id: string) =>
    activeHash ? activeHash === id : items[0]?.id === id;

  const scrollToItem = (event: MouseEvent, id: string) => {
    const target =
      typeof document !== "undefined" ? document.getElementById(id) : null;
    if (!target) return;
    event.preventDefault();
    activeHash = id;
    target.scrollIntoView({ behavior: "smooth", block: "start" });
    window.history.replaceState(null, "", `#${id}`);
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
        {@const active = isActive(item.id)}
        <a
          href={`#${item.id}`}
          data-settings-subnav-item
          data-active={active}
          onclick={(event) => scrollToItem(event, item.id)}
          class={`inline-flex min-h-10 shrink-0 items-center rounded-full px-3 py-2 text-sm font-medium transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${
            active
              ? "bg-surface-100 text-surface-content"
              : "bg-surface/70 text-muted hover:text-surface-content"
          }`}
        >
          {item.label}
        </a>
      {/each}
    </div>
  </nav>
{/if}
