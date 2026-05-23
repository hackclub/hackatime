<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import UserSearch from "./AccountMerger/UserSearch.svelte";
  import type { UserResult } from "./AccountMerger/types";
  import { adminAccountMerger } from "../../api";

  const searchUrl = adminAccountMerger.searchUsers.path();
  const mergeUrl = adminAccountMerger.merge.path();

  let olderUser = $state<UserResult | null>(null);
  let newerUser = $state<UserResult | null>(null);
  let confirmOpen = $state(false);
  let merging = $state(false);

  const orderError = $derived.by<string | null>(() => {
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
  const canMerge = $derived(
    olderUser !== null && newerUser !== null && !orderError,
  );

  function handleMerge() {
    merging = true;
    router.post(
      mergeUrl,
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
      <div>
        <h2 class="mb-4 text-xl font-semibold text-green">← OLDER (Keep)</h2>
        <p class="mb-3 text-sm text-muted">
          This account will receive the heartbeats and be kept.
        </p>
        <UserSearch
          side="older"
          {searchUrl}
          accent="green"
          bind:selected={olderUser}
        />
      </div>

      <div>
        <h2 class="mb-4 text-xl font-semibold text-red">NEWER (Delete) →</h2>
        <p class="mb-3 text-sm text-muted">
          This account's heartbeats will be moved, sessions revoked, then
          deleted.
        </p>
        <UserSearch
          side="newer"
          {searchUrl}
          accent="red"
          bind:selected={newerUser}
        />
      </div>
    </div>

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
    {#snippet newer()}
      <span class="font-semibold text-red">NEWER</span>
    {/snippet}
    {#snippet older()}
      <span class="font-semibold text-green">OLDER</span>
    {/snippet}
    <ol class="list-inside list-decimal space-y-2 text-sm text-muted">
      <li>
        All heartbeats from the {@render newer()} account are transferred to the
        {@render older()} account
      </li>
      <li>
        All sessions and API tokens for the {@render newer()} account are revoked
      </li>
      <li>
        All related data (email addresses, goals, API keys, imports, etc.) for
        the
        {@render newer()} account are deleted
      </li>
      <li>The {@render newer()} account is permanently deleted</li>
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
