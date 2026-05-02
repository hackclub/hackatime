<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";

  let { search_url, merge_url }: { search_url: string; merge_url: string } =
    $props();

  type UserResult = {
    id: number;
    display_name: string;
    avatar_url: string | null;
    created_at: string | null;
    username: string;
    email: string | null;
  };

  let olderUser = $state<UserResult | null>(null);
  let newerUser = $state<UserResult | null>(null);

  let olderQuery = $state("");
  let newerQuery = $state("");
  let olderResults = $state<UserResult[]>([]);
  let newerResults = $state<UserResult[]>([]);
  let olderOpen = $state(false);
  let newerOpen = $state(false);
  let olderHighlight = $state(-1);
  let newerHighlight = $state(-1);

  let confirmOpen = $state(false);
  let merging = $state(false);

  let olderTimer: ReturnType<typeof setTimeout> | undefined = undefined;
  let newerTimer: ReturnType<typeof setTimeout> | undefined = undefined;

  async function doSearch(query: string, side: "older" | "newer") {
    if (!query.trim()) {
      if (side === "older") olderOpen = false;
      else newerOpen = false;
      return;
    }

    try {
      const res = await fetch(
        `${search_url}?query=${encodeURIComponent(query.trim())}`,
      );
      if (!res.ok) throw new Error(`Search failed with ${res.status}`);

      const users: UserResult[] = await res.json();

      if (side === "older") {
        olderResults = users;
        olderOpen = true;
        olderHighlight = -1;
      } else {
        newerResults = users;
        newerOpen = true;
        newerHighlight = -1;
      }
    } catch {
      if (side === "older") {
        olderResults = [];
        olderOpen = false;
        olderHighlight = -1;
      } else {
        newerResults = [];
        newerOpen = false;
        newerHighlight = -1;
      }
    }
  }

  function onOlderInput() {
    clearTimeout(olderTimer);
    olderTimer = setTimeout(() => doSearch(olderQuery, "older"), 200);
  }

  function onNewerInput() {
    clearTimeout(newerTimer);
    newerTimer = setTimeout(() => doSearch(newerQuery, "newer"), 200);
  }

  function selectUser(user: UserResult, side: "older" | "newer") {
    if (side === "older") {
      olderUser = user;
      olderQuery = "";
      olderOpen = false;
    } else {
      newerUser = user;
      newerQuery = "";
      newerOpen = false;
    }
  }

  function clearUser(side: "older" | "newer") {
    if (side === "older") olderUser = null;
    else newerUser = null;
  }

  function handleKeydown(e: KeyboardEvent, side: "older" | "newer") {
    const results = side === "older" ? olderResults : newerResults;
    const highlight = side === "older" ? olderHighlight : newerHighlight;

    if (e.key === "ArrowDown") {
      e.preventDefault();
      const next = Math.min(highlight + 1, results.length - 1);
      if (side === "older") olderHighlight = next;
      else newerHighlight = next;
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      const next = Math.max(highlight - 1, 0);
      if (side === "older") olderHighlight = next;
      else newerHighlight = next;
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (highlight >= 0 && highlight < results.length) {
        selectUser(results[highlight], side);
      }
    } else if (e.key === "Escape") {
      if (side === "older") olderOpen = false;
      else newerOpen = false;
    }
  }

  function handleMerge() {
    merging = true;
    router.post(
      merge_url,
      { older_id: olderUser!.id, newer_id: newerUser!.id },
      {
        onFinish: () => {
          merging = false;
          confirmOpen = false;
          olderUser = null;
          newerUser = null;
        },
      },
    );
  }

  let orderError = $derived.by<string | null>(() => {
    if (!olderUser || !newerUser) return null;
    if (olderUser.id === newerUser.id)
      return "Cannot merge a user into themselves.";
    if (
      newerUser.created_at &&
      olderUser.created_at &&
      newerUser.created_at < olderUser.created_at
    )
      return `"${newerUser.display_name}" was created on ${newerUser.created_at}, which is before "${olderUser.display_name}" (created ${olderUser.created_at}). The "newer" account must have been created after the "older" account. Swap them or pick different accounts.`;
    return null;
  });
  let canMerge = $derived(
    olderUser !== null && newerUser !== null && !orderError,
  );
</script>

<svelte:head>
  <title>Account Merger</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6">
  <header class="mb-8 text-center">
    <h1 class="text-4xl font-bold text-surface-content">Account Merger</h1>
    <p class="mt-2 text-muted">
      Merge a newer account's heartbeats into an older account, then delete the
      newer account.
    </p>
  </header>

  <div class="rounded-xl border border-primary bg-dark p-6">
    <div class="grid grid-cols-2 gap-8">
      <!-- OLDER (Left) -->
      <div>
        <h2 class="mb-4 text-xl font-semibold text-green">← OLDER (Keep)</h2>
        <p class="mb-3 text-sm text-muted">
          This account will receive the heartbeats and be kept.
        </p>
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
              placeholder="Search by name/email/id..."
              data-testid="older-search"
              bind:value={olderQuery}
              oninput={onOlderInput}
              onkeydown={(e) => handleKeydown(e, "older")}
              autocomplete="off"
              class="w-full rounded-lg border border-surface-200 bg-input py-2 pl-10 pr-3 text-sm text-surface-content placeholder-gray-500 focus:border-primary focus:outline-none"
            />
          </div>
          {#if olderOpen && olderResults.length > 0}
            <div
              class="absolute left-0 top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-surface-200 bg-dark shadow-lg"
            >
              {#each olderResults as user, i}
                <button
                  type="button"
                  data-testid={`older-result-${user.id}`}
                  class="flex w-full cursor-pointer items-center gap-3 p-3 transition-colors hover:bg-surface-100/50 {i ===
                  olderHighlight
                    ? 'bg-surface-100/50'
                    : ''}"
                  onclick={() => selectUser(user, "older")}
                >
                  {#if user.avatar_url}
                    <img
                      src={user.avatar_url}
                      alt=""
                      class="h-8 w-8 rounded-full"
                    />
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
          {:else if olderOpen && olderResults.length === 0}
            <div
              class="absolute left-0 top-full z-50 mt-1 w-full rounded-lg border border-surface-200 bg-dark p-3 text-center text-sm text-muted shadow-lg"
            >
              No users found
            </div>
          {/if}
        </div>
        <div class="mt-4">
          {#if olderUser}
            <div class="rounded-lg border border-green/30 bg-green/10 p-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  {#if olderUser.avatar_url}
                    <img
                      src={olderUser.avatar_url}
                      alt=""
                      class="h-12 w-12 rounded-full"
                    />
                  {:else}
                    <div class="h-12 w-12 rounded-full bg-surface-100"></div>
                  {/if}
                  <div>
                    <div class="text-lg font-semibold text-surface-content">
                      {olderUser.display_name}
                    </div>
                    <div class="text-sm text-muted">ID: {olderUser.id}</div>
                    {#if olderUser.created_at}
                      <div class="text-xs text-muted">
                        Created: {olderUser.created_at}
                      </div>
                    {/if}
                    {#if olderUser.email}
                      <div class="text-xs text-muted">{olderUser.email}</div>
                    {/if}
                  </div>
                </div>
                <button
                  type="button"
                  class="cursor-pointer text-sm text-muted hover:text-red"
                  onclick={() => clearUser("older")}
                >
                  ✕ Clear
                </button>
              </div>
            </div>
          {:else}
            <div
              class="rounded-lg border border-dashed border-surface-200 py-8 text-center text-sm text-muted"
            >
              No user selected
            </div>
          {/if}
        </div>
      </div>

      <!-- NEWER (Right) -->
      <div>
        <h2 class="mb-4 text-xl font-semibold text-red">NEWER (Delete) →</h2>
        <p class="mb-3 text-sm text-muted">
          This account's heartbeats will be moved, sessions revoked, then
          deleted.
        </p>
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
              placeholder="Search by name/email/id..."
              data-testid="newer-search"
              bind:value={newerQuery}
              oninput={onNewerInput}
              onkeydown={(e) => handleKeydown(e, "newer")}
              autocomplete="off"
              class="w-full rounded-lg border border-surface-200 bg-input py-2 pl-10 pr-3 text-sm text-surface-content placeholder-gray-500 focus:border-primary focus:outline-none"
            />
          </div>
          {#if newerOpen && newerResults.length > 0}
            <div
              class="absolute left-0 top-full z-50 mt-1 max-h-48 w-full overflow-y-auto rounded-lg border border-surface-200 bg-dark shadow-lg"
            >
              {#each newerResults as user, i}
                <button
                  type="button"
                  data-testid={`newer-result-${user.id}`}
                  class="flex w-full cursor-pointer items-center gap-3 p-3 transition-colors hover:bg-surface-100/50 {i ===
                  newerHighlight
                    ? 'bg-surface-100/50'
                    : ''}"
                  onclick={() => selectUser(user, "newer")}
                >
                  {#if user.avatar_url}
                    <img
                      src={user.avatar_url}
                      alt=""
                      class="h-8 w-8 rounded-full"
                    />
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
          {:else if newerOpen && newerResults.length === 0}
            <div
              class="absolute left-0 top-full z-50 mt-1 w-full rounded-lg border border-surface-200 bg-dark p-3 text-center text-sm text-muted shadow-lg"
            >
              No users found
            </div>
          {/if}
        </div>
        <div class="mt-4">
          {#if newerUser}
            <div class="rounded-lg border border-red/30 bg-red/10 p-4">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                  {#if newerUser.avatar_url}
                    <img
                      src={newerUser.avatar_url}
                      alt=""
                      class="h-12 w-12 rounded-full"
                    />
                  {:else}
                    <div class="h-12 w-12 rounded-full bg-surface-100"></div>
                  {/if}
                  <div>
                    <div class="text-lg font-semibold text-surface-content">
                      {newerUser.display_name}
                    </div>
                    <div class="text-sm text-muted">ID: {newerUser.id}</div>
                    {#if newerUser.created_at}
                      <div class="text-xs text-muted">
                        Created: {newerUser.created_at}
                      </div>
                    {/if}
                    {#if newerUser.email}
                      <div class="text-xs text-muted">{newerUser.email}</div>
                    {/if}
                  </div>
                </div>
                <button
                  type="button"
                  class="cursor-pointer text-sm text-muted hover:text-red"
                  onclick={() => clearUser("newer")}
                >
                  ✕ Clear
                </button>
              </div>
            </div>
          {:else}
            <div
              class="rounded-lg border border-dashed border-surface-200 py-8 text-center text-sm text-muted"
            >
              No user selected
            </div>
          {/if}
        </div>
      </div>
    </div>

    <!-- Merge Arrow & Button -->
    <div
      class="mt-8 flex flex-col items-center border-t border-surface-200 pt-6"
    >
      <div class="mb-4 text-4xl">←</div>
      <p class="mb-4 text-sm text-muted">
        Heartbeats flow from <span class="font-semibold text-red">NEWER</span>
        to <span class="font-semibold text-green">OLDER</span>
      </p>
      {#if orderError}
        <div
          class="mb-4 rounded-lg border border-red/30 bg-red/10 px-4 py-3 text-sm text-red"
        >
          ⚠️ {orderError}
        </div>
      {/if}
      <Button
        type="button"
        variant="primary"
        data-testid="open-merge-confirmation"
        size="lg"
        class="!border-red !bg-red !text-on-primary hover:!opacity-90"
        disabled={!canMerge}
        onclick={() => (confirmOpen = true)}
      >
        Merge & Delete
      </Button>
    </div>
  </div>

  <div class="rounded-xl border border-surface-200 bg-dark p-6">
    <h3 class="mb-3 text-lg font-semibold text-surface-content">
      What happens during a merge?
    </h3>
    <ol class="list-inside list-decimal space-y-2 text-sm text-muted">
      <li>
        All heartbeats from the <span class="font-semibold text-red">NEWER</span
        >
        account are transferred to the
        <span class="font-semibold text-green">OLDER</span> account
      </li>
      <li>
        All sessions and API tokens for the <span class="font-semibold text-red"
          >NEWER</span
        > account are revoked
      </li>
      <li>
        All related data (email addresses, goals, API keys, imports, etc.) for
        the <span class="font-semibold text-red">NEWER</span> account are deleted
      </li>
      <li>
        The <span class="font-semibold text-red">NEWER</span> account is permanently
        deleted
      </li>
    </ol>
  </div>
</div>

<Modal
  bind:open={confirmOpen}
  title="Confirm Account Merge"
  description="This action cannot be undone."
  hasBody={true}
  hasActions={true}
>
  {#snippet body()}
    <p class="text-sm text-muted">
      Are you <strong>ABSOLUTELY</strong> sure? This will move all heartbeats
      from
      <strong class="text-red"
        >{newerUser?.display_name} (#{newerUser?.id})</strong
      >
      to
      <strong class="text-green"
        >{olderUser?.display_name} (#{olderUser?.id})</strong
      >, revoke all sessions, and <strong>PERMANENTLY DELETE</strong> the newer account.
    </p>
  {/snippet}
  {#snippet actions()}
    <div class="flex items-center justify-end gap-3">
      <Button
        type="button"
        variant="surface"
        onclick={() => (confirmOpen = false)}
      >
        Cancel
      </Button>
      <Button
        type="button"
        variant="primary"
        data-testid="confirm-merge"
        class="!border-red !bg-red !text-on-primary hover:!opacity-90"
        disabled={merging}
        onclick={handleMerge}
      >
        {merging ? "Merging…" : "Merge & Delete"}
      </Button>
    </div>
  {/snippet}
</Modal>
