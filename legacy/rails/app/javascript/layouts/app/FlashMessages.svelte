<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import type { LayoutNav } from "../../types";

  let { flash }: { flash: LayoutNav["flash"] } = $props();

  const HIDE_DELAY = 6000;
  const EXIT_MS = 250;

  let visible = $state(false);
  let hiding = $state(false);
  let items = $state<LayoutNav["flash"]>([]);
  let signature = "";
  let hideId: ReturnType<typeof setTimeout> | undefined;
  let removeId: ReturnType<typeof setTimeout> | undefined;

  const sig = (f: LayoutNav["flash"]) =>
    JSON.stringify(f.map(({ message, class_name }) => [message, class_name]));

  $effect(() => {
    if (!flash.length) return;
    const next = sig(flash);
    if (next === signature) return;
    signature = next;
    if (hideId) clearTimeout(hideId);
    if (removeId) clearTimeout(removeId);
    items = flash;
    visible = true;
    hiding = false;
    router.replaceProp("layout.nav.flash", []);
    hideId = setTimeout(() => {
      hiding = true;
      removeId = setTimeout(() => {
        visible = false;
        hiding = false;
        items = [];
        signature = "";
      }, EXIT_MS);
    }, HIDE_DELAY);
  });

  $effect(() => () => {
    if (hideId) clearTimeout(hideId);
    if (removeId) clearTimeout(removeId);
  });
</script>

{#if visible && items.length > 0}
  <div
    class="fixed top-4 left-1/2 transform -translate-x-1/2 z-50 w-full max-w-md px-4 space-y-2"
  >
    {#each items as item}
      <div
        class={`flash-message shadow-lg flash-message--enter ${hiding ? "flash-message--leaving" : ""} ${item.class_name}`}
      >
        {item.message}
      </div>
    {/each}
  </div>
{/if}
