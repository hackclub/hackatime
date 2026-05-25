<script lang="ts" module>
  export type UserPickerResult = {
    id: number;
    display_name: string;
    avatar_url: string | null;
    created_at: string | null;
    username: string | null;
    email: string | null;
    leaderboard_shadowbanned?: boolean;
    leaderboard_shadowban_reason?: string | null;
  };
</script>

<script lang="ts">
  type Accent = "primary" | "green" | "red";

  let {
    searchUrl,
    selected = $bindable<UserPickerResult | null>(null),
    placeholder = "Search by name/email/id...",
    testid = "user-picker",
    accent = "primary",
    emptyText = "No user selected",
  }: {
    searchUrl: string;
    selected?: UserPickerResult | null;
    placeholder?: string;
    testid?: string;
    accent?: Accent;
    emptyText?: string;
  } = $props();

  let query = $state("");
  let results = $state<UserPickerResult[]>([]);
  let open = $state(false);
  let highlight = $state(-1);
  let timer: ReturnType<typeof setTimeout> | undefined = undefined;

  let selectedClass = $derived.by(() => {
    if (accent === "green") return "border-green/30 bg-green/10";
    if (accent === "red") return "border-red/30 bg-red/10";
    return "border-primary/30 bg-primary/10";
  });

  async function doSearch(searchQuery: string) {
    if (!searchQuery.trim()) {
      open = false;
      results = [];
      highlight = -1;
      return;
    }

    try {
      const res = await fetch(
        `${searchUrl}?query=${encodeURIComponent(searchQuery.trim())}`,
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

  function onInput() {
    clearTimeout(timer);
    timer = setTimeout(() => doSearch(query), 200);
  }

  function selectUser(user: UserPickerResult) {
    selected = user;
    query = "";
    open = false;
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      highlight = Math.min(highlight + 1, results.length - 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      highlight = Math.max(highlight - 1, 0);
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (highlight >= 0 && highlight < results.length) {
        selectUser(results[highlight]);
      }
    } else if (e.key === "Escape") {
      open = false;
    }
  }
</script>

<div class="relative">
  <div class="relative">
    <div
      class="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-muted"
    >
      <svg
        class="h-4 w-4"
        fill="none"
        stroke="currentColor"
        viewBox="0 0 24 24"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          stroke-width="2"
          d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
        ></path>
      </svg>
    </div>
    <input
      type="text"
      {placeholder}
      data-testid={`${testid}-search`}
      bind:value={query}
      oninput={onInput}
      onkeydown={handleKeydown}
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
          data-testid={`${testid}-result-${user.id}`}
          class="flex w-full cursor-pointer items-center gap-3 p-3 transition-colors hover:bg-surface-100/50 {i ===
          highlight
            ? 'bg-surface-100/50'
            : ''}"
          onclick={() => selectUser(user)}
        >
          {#if user.avatar_url}
            <img src={user.avatar_url} alt="" class="h-8 w-8 rounded-full" />
          {:else}
            <div class="h-8 w-8 rounded-full bg-surface-100"></div>
          {/if}
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
  {:else if open && results.length === 0}
    <div
      class="absolute left-0 top-full z-50 mt-1 w-full rounded-lg border border-surface-200 bg-dark p-3 text-center text-sm text-muted shadow-lg"
    >
      No users found
    </div>
  {/if}
</div>

<div class="mt-4">
  {#if selected}
    <div class="rounded-lg border p-4 {selectedClass}">
      <div class="flex items-center justify-between gap-4">
        <div class="flex min-w-0 items-center gap-3">
          {#if selected.avatar_url}
            <img
              src={selected.avatar_url}
              alt=""
              class="h-12 w-12 rounded-full"
            />
          {:else}
            <div class="h-12 w-12 rounded-full bg-surface-100"></div>
          {/if}
          <div class="min-w-0">
            <div class="truncate text-lg font-semibold text-surface-content">
              {selected.display_name}
            </div>
            <div class="text-sm text-muted">ID: {selected.id}</div>
            {#if selected.created_at}
              <div class="text-xs text-muted">
                Created: {selected.created_at}
              </div>
            {/if}
            {#if selected.email}
              <div class="truncate text-xs text-muted">{selected.email}</div>
            {/if}
          </div>
        </div>
        <button
          type="button"
          class="shrink-0 cursor-pointer text-sm text-muted hover:text-red"
          onclick={() => (selected = null)}
        >
          Clear
        </button>
      </div>
    </div>
  {:else}
    <div
      class="rounded-lg border border-dashed border-surface-200 py-8 text-center text-sm text-muted"
    >
      {emptyText}
    </div>
  {/if}
</div>
