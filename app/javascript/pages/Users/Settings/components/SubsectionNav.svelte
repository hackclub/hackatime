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
          class={`inline-flex min-h-10 shrink-0 items-center rounded-full px-3 py-2 text-sm font-medium transition-[background-color,color,box-shadow,transform] duration-150 ease-[cubic-bezier(0.2,0,0,1)] active:scale-[0.96] ${
            isActive(item.id)
              ? "bg-surface-100 text-surface-content shadow-[inset_0_0_0_1px_rgba(255,255,255,0.1),0_8px_20px_rgba(0,0,0,0.1)]"
              : "bg-surface/70 text-muted shadow-[inset_0_0_0_1px_rgba(255,255,255,0.06)] hover:text-surface-content hover:shadow-[inset_0_0_0_1px_rgba(255,255,255,0.1)]"
          }`}
        >
          {item.label}
        </a>
      {/each}
    </div>
  </nav>
{/if}
