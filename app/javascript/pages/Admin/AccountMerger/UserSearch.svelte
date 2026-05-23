<script lang="ts">
  import type { Side, UserResult } from "./types";
  import Search from "hcicons-svelte/search";

  let {
    side,
    searchUrl,
    selected = $bindable<UserResult | null>(null),
    accent,
  }: {
    side: Side;
    searchUrl: string;
    selected?: UserResult | null;
    accent: "green" | "red";
  } = $props();

  let query = $state("");
  let results = $state<UserResult[]>([]);
  let open = $state(false);
  let highlight = $state(-1);
  let timer: ReturnType<typeof setTimeout> | undefined;

  const ring = $derived(
    accent === "green"
      ? "border-green/30 bg-green/10"
      : "border-red/30 bg-red/10",
  );

  async function doSearch(q: string) {
    if (!q.trim()) return ((open = false), undefined);
    try {
      const res = await fetch(
        `${searchUrl}?query=${encodeURIComponent(q.trim())}`,
      );
      if (!res.ok) throw new Error(`Search failed with ${res.status}`);
      results = await res.json();
      open = true;
      highlight = -1;
    } catch {
      results = [];
      open = false;
      highlight = -1;
    }
  }

  function pick(user: UserResult) {
    selected = user;
    query = "";
    open = false;
  }

  function onKeydown(e: KeyboardEvent) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      highlight = Math.min(highlight + 1, results.length - 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      highlight = Math.max(highlight - 1, 0);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (highlight >= 0 && highlight < results.length)
        pick(results[highlight]);
    } else if (e.key === "Escape") open = false;
  }
</script>

{#snippet avatar(url: string | null, size: "sm" | "lg")}
  {@const cls = size === "sm" ? "h-8 w-8" : "h-12 w-12"}
  {#if url}
    <img src={url} alt="" class="{cls} rounded-full" />
  {:else}
    <div class="{cls} rounded-full bg-surface-100"></div>
  {/if}
{/snippet}

<div class="relative">
  <div class="relative">
    <div
      class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted"
    >
      <Search size={16} />
    </div>
    <input
      type="text"
      placeholder="Search by name/email/id..."
      data-testid="{side}-search"
      bind:value={query}
      oninput={() => {
        clearTimeout(timer);
        timer = setTimeout(() => doSearch(query), 200);
      }}
      onkeydown={onKeydown}
      autocomplete="off"
      class="w-full rounded-lg border border-surface-200 bg-input py-2 pl-10 pr-3 text-sm text-surface-content placeholder-gray-500 focus:border-primary focus:outline-none"
    />
  </div>
  {#if open && results.length > 0}
    <div
      class="absolute left-0 top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-surface-200 bg-dark shadow-lg"
    >
      {#each results as user, i}
        <button
          type="button"
          data-testid={`${side}-result-${user.id}`}
          class="flex w-full cursor-pointer items-center gap-3 p-3 transition-colors hover:bg-surface-100/50 {i ===
          highlight
            ? 'bg-surface-100/50'
            : ''}"
          onclick={() => pick(user)}
        >
          {@render avatar(user.avatar_url, "sm")}
          <div class="text-left">
            <div class="font-medium text-surface-content">
              {user.display_name}
            </div>
            <div class="text-xs text-muted">
              ID: {user.id}{user.created_at
                ? ` · Created: ${user.created_at}`
                : ""}
            </div>
          </div>
        </button>
      {/each}
    </div>
  {:else if open}
    <div
      class="absolute left-0 top-full z-50 mt-1 w-full rounded-lg border border-surface-200 bg-dark p-3 text-center text-sm text-muted shadow-lg"
    >
      No users found
    </div>
  {/if}
</div>
<div class="mt-4">
  {#if selected}
    <div class="rounded-lg border {ring} p-4 flex items-center justify-between">
      <div class="flex items-center gap-3">
        {@render avatar(selected.avatar_url, "lg")}
        <div>
          <div class="text-lg font-semibold text-surface-content">
            {selected.display_name}
          </div>
          <div class="text-sm text-muted">ID: {selected.id}</div>
          {#if selected.created_at}
            <div class="text-xs text-muted">Created: {selected.created_at}</div>
          {/if}
          {#if selected.email}
            <div class="text-xs text-muted">{selected.email}</div>
          {/if}
        </div>
      </div>
      <button
        type="button"
        class="cursor-pointer text-sm text-muted hover:text-red"
        onclick={() => (selected = null)}>✕ Clear</button
      >
    </div>
  {:else}
    <div
      class="rounded-lg border border-dashed border-surface-200 py-8 text-center text-sm text-muted"
    >
      No user selected
    </div>
  {/if}
</div>
