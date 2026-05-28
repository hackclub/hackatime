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

  type Props = {
    searchUrl: string;
    selected?: UserPickerResult | null;
    placeholder?: string;
    id?: string;
    label?: string;
    accent?: Accent;
    emptyText?: string;
  };

  let {
    searchUrl,
    selected = $bindable<UserPickerResult | null>(null),
    placeholder = "Search by name/email/id...",
    id = "user-picker",
    label = "Search users",
    accent = "primary",
    emptyText = "No user selected",
  }: Props = $props();

  let query = $state("");
  let results = $state<UserPickerResult[]>([]);
  let open = $state(false);
  let highlight = $state(-1);
  let timer: ReturnType<typeof setTimeout> | undefined;

  const dropdownBase = "absolute left-0 top-full z-50 mt-1";
  const dropdownPanel = "rounded-lg border border-surface-200 bg-dark";
  let listboxId = $derived(`${id}-results`);

  let selectedClass = $derived(
    accent === "green"
      ? "border-green/30 bg-green/10"
      : accent === "red"
        ? "border-red/30 bg-red/10"
        : "border-primary/30 bg-primary/10",
  );

  let dropdownClass = $derived(
    results.length
      ? `${dropdownBase} max-h-48 w-full overflow-y-auto ${dropdownPanel} shadow-lg`
      : `${dropdownBase} w-full ${dropdownPanel} p-3 text-center text-sm text-muted shadow-lg`,
  );

  let activeDescendant = $derived(
    open && highlight >= 0 && highlight < results.length
      ? `${id}-result-${results[highlight].id}`
      : undefined,
  );

  $effect(() => () => clearTimeout(timer));

  function resetSearch() {
    open = false;
    results = [];
    highlight = -1;
  }

  async function doSearch(searchQuery: string) {
    const trimmed = searchQuery.trim();
    if (!trimmed) return resetSearch();

    try {
      const res = await fetch(
        `${searchUrl}?query=${encodeURIComponent(trimmed)}`,
      );
      if (!res.ok) throw new Error(`Search failed with ${res.status}`);

      results = await res.json();
      open = true;
      highlight = -1;
    } catch {
      resetSearch();
    }
  }

  function onInput() {
    clearTimeout(timer);
    timer = setTimeout(() => void doSearch(query), 200);
  }

  function selectUser(user: UserPickerResult) {
    selected = user;
    query = "";
    open = false;
  }

  function handleOptionKeydown(e: KeyboardEvent, user: UserPickerResult) {
    if (e.key !== "Enter" && e.key !== " ") return;

    e.preventDefault();
    selectUser(user);
  }

  function handleKeydown(e: KeyboardEvent) {
    if (e.key === "Escape") {
      open = false;
      return;
    }

    if (e.key !== "ArrowDown" && e.key !== "ArrowUp" && e.key !== "Enter")
      return;

    e.preventDefault();

    if (e.key === "ArrowDown")
      highlight = Math.min(highlight + 1, results.length - 1);
    else if (e.key === "ArrowUp") highlight = Math.max(highlight - 1, 0);
    else if (highlight >= 0 && highlight < results.length)
      selectUser(results[highlight]);
  }
</script>

{#snippet avatar(user: UserPickerResult, className: string)}
  {#if user.avatar_url}
    <img src={user.avatar_url} alt="" class={className} />
  {:else}
    <div class="{className} bg-surface-100"></div>
  {/if}
{/snippet}

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
    <label for={id} class="sr-only">{label}</label>
    <input
      {id}
      type="text"
      {placeholder}
      bind:value={query}
      oninput={onInput}
      onkeydown={handleKeydown}
      autocomplete="off"
      role="combobox"
      aria-autocomplete="list"
      aria-controls={listboxId}
      aria-expanded={open}
      aria-activedescendant={activeDescendant}
      class="w-full rounded-lg border border-surface-200 bg-input py-2 pl-10 pr-3 text-sm text-surface-content placeholder-gray-500 focus:border-primary focus:outline-none"
    />
  </div>

  {#if open}
    <div id={listboxId} class={dropdownClass} role="listbox" aria-label={label}>
      {#if results.length}
        {#each results as user, i}
          <div
            id={`${id}-result-${user.id}`}
            role="option"
            tabindex="-1"
            aria-selected={i === highlight}
            class="flex w-full cursor-pointer items-center gap-3 p-3 transition-colors hover:bg-surface-100/50 {i ===
            highlight
              ? 'bg-surface-100/50'
              : ''}"
            onclick={() => selectUser(user)}
            onkeydown={(e) => handleOptionKeydown(e, user)}
          >
            {@render avatar(user, "h-8 w-8 rounded-full")}
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
          </div>
        {/each}
      {:else}
        No users found
      {/if}
    </div>
  {/if}
</div>

<div class="mt-4">
  {#if selected}
    <div class="rounded-lg border p-4 {selectedClass}">
      <div class="flex items-center justify-between gap-4">
        <div class="flex min-w-0 items-center gap-3">
          {@render avatar(selected, "h-12 w-12 rounded-full")}
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
