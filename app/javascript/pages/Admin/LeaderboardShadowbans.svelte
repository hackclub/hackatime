<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import UserPicker, {
    type UserPickerResult,
  } from "../../components/UserPicker.svelte";
  import { adminLeaderboardShadowbans } from "../../api";
  import ShadowbannedUsersTable, {
    type ShadowbannedUser,
  } from "./LeaderboardShadowbans/ShadowbannedUsersTable.svelte";

  let {
    shadowbanned_users,
  }: {
    shadowbanned_users: ShadowbannedUser[];
  } = $props();

  const searchUrl = adminLeaderboardShadowbans.searchUsers.path();
  const createUrl = adminLeaderboardShadowbans.create.path();
  const redButtonClass =
    "!border-red !bg-red !text-on-primary hover:!opacity-90";

  let selectedUser = $state<UserPickerResult | null>(null);
  let reason = $state("");
  let confirmBanOpen = $state(false);
  let unbanUser = $state<ShadowbannedUser | null>(null);
  let unbanOpen = $state(false);
  let submitting = $state(false);

  let trimmedReason = $derived(reason.trim());
  let canSubmit = $derived(selectedUser !== null && trimmedReason.length > 0);

  function resetBanForm() {
    selectedUser = null;
    reason = "";
  }

  function cancelBan() {
    confirmBanOpen = false;
  }

  function confirmUnban(user: ShadowbannedUser) {
    unbanUser = user;
    unbanOpen = true;
  }

  function cancelUnban() {
    unbanUser = null;
    unbanOpen = false;
  }

  function submitShadowban() {
    if (!selectedUser) return;

    submitting = true;
    router.post(
      createUrl,
      { user_id: selectedUser.id, reason: trimmedReason },
      {
        onFinish: () => {
          submitting = false;
          confirmBanOpen = false;
          resetBanForm();
        },
      },
    );
  }

  function submitUnban() {
    if (!unbanUser) return;

    submitting = true;
    router.delete(
      adminLeaderboardShadowbans.destroy.path({ user_id: unbanUser.id }),
      {
        onFinish: () => {
          submitting = false;
          cancelUnban();
        },
      },
    );
  }
</script>

{#snippet modalActions(
  cancel: () => void,
  confirm: () => void,
  label: string,
  loadingLabel: string,
  className = "",
)}
  <div class="flex justify-end gap-3">
    <Button type="button" variant="surface" onclick={cancel}>Cancel</Button>
    <Button
      type="button"
      variant="primary"
      class={className}
      disabled={submitting}
      onclick={confirm}
    >
      {submitting ? loadingLabel : label}
    </Button>
  </div>
{/snippet}

<svelte:head>
  <title>Leaderboard Shadowbans</title>
</svelte:head>

<div class="mx-auto max-w-5xl space-y-6">
  <header class="text-center">
    <h1 class="text-4xl font-bold text-surface-content">
      leaderboard shadowbans
    </h1>
    <p class="mt-2 text-muted">hide users from the leaderboards!</p>
  </header>

  <section class="rounded-xl border border-primary bg-dark p-6">
    <h2 class="mb-4 text-xl font-semibold text-surface-content">
      Add a leaderboard shadowban
    </h2>

    <UserPicker
      bind:selected={selectedUser}
      {searchUrl}
      id="shadowban-user"
      label="User to shadowban"
      accent="red"
    />

    {#if selectedUser?.leaderboard_shadowbanned}
      <div
        class="mt-4 rounded-lg border border-yellow/30 bg-yellow/10 p-3 text-sm text-yellow"
      >
        This user is already leaderboard shadowbanned.
      </div>
    {/if}

    <label
      class="mt-6 block text-sm font-medium text-surface-content"
      for="shadowban-reason"
    >
      Reason
    </label>
    <textarea
      id="shadowban-reason"
      bind:value={reason}
      rows="4"
      placeholder="Why should this user be hidden from public leaderboards?"
      class="mt-2 w-full rounded-lg border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content placeholder-gray-500 focus:border-primary focus:outline-none"
    ></textarea>

    <div class="mt-4 flex justify-end">
      <Button
        type="button"
        variant="primary"
        class={redButtonClass}
        disabled={!canSubmit || selectedUser?.leaderboard_shadowbanned}
        onclick={() => (confirmBanOpen = true)}
      >
        Shadowban from leaderboards
      </Button>
    </div>
  </section>

  <section class="rounded-xl border border-surface-200 bg-dark p-6">
    <div class="mb-4 flex items-center justify-between gap-4">
      <div>
        <h2 class="text-xl font-semibold text-surface-content">
          Currently shadowbanned
        </h2>
        <p class="text-sm text-muted">
          Latest 100 users hidden from public leaderboards.
        </p>
      </div>
      <div
        class="rounded-full border border-surface-200 px-3 py-1 text-sm text-muted"
      >
        {shadowbanned_users.length} users
      </div>
    </div>

    <ShadowbannedUsersTable
      users={shadowbanned_users}
      onRemove={confirmUnban}
    />
  </section>
</div>

<Modal
  bind:open={confirmBanOpen}
  title="Confirm leaderboard shadowban"
  description="This user will be hidden from everyone else's leaderboard view."
  hasBody={true}
  hasActions={true}
>
  {#snippet body()}
    <div class="space-y-3 text-sm text-muted">
      <p>
        Shadowban
        <strong class="text-surface-content"
          >{selectedUser?.display_name}</strong
        >
        from public leaderboards?
      </p>
      <p class="rounded-lg border border-surface-200 bg-surface-100/20 p-3">
        {trimmedReason}
      </p>
    </div>
  {/snippet}
  {#snippet actions()}
    {@render modalActions(
      cancelBan,
      submitShadowban,
      "Confirm shadowban",
      "Saving...",
      redButtonClass,
    )}
  {/snippet}
</Modal>

<Modal
  bind:open={unbanOpen}
  title="Remove leaderboard shadowban"
  description="This user will become visible to other leaderboard viewers again."
  hasBody={true}
  hasActions={true}
>
  {#snippet body()}
    <p class="text-sm text-muted">
      Remove the leaderboard shadowban for
      <strong class="text-surface-content">{unbanUser?.display_name}</strong>?
    </p>
  {/snippet}
  {#snippet actions()}
    {@render modalActions(
      cancelUnban,
      submitUnban,
      "Remove shadowban",
      "Removing...",
    )}
  {/snippet}
</Modal>
