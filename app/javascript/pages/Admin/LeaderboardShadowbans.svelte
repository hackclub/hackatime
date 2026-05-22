<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import UserPicker, {
    type UserPickerResult,
  } from "../../components/UserPicker.svelte";
  import { adminLeaderboardShadowbans } from "../../api";

  type ShadowbannedUser = UserPickerResult & {
    leaderboard_shadowbanned: boolean;
    leaderboard_shadowban_reason: string | null;
    updated_at: string | null;
  };

  let {
    shadowbanned_users,
  }: {
    shadowbanned_users: ShadowbannedUser[];
  } = $props();

  const searchUrl = adminLeaderboardShadowbans.searchUsers.path();
  const createUrl = adminLeaderboardShadowbans.create.path();
  const destroyUrl = adminLeaderboardShadowbans.destroy.path();

  let selectedUser = $state<UserPickerResult | null>(null);
  let reason = $state("");
  let confirmBanOpen = $state(false);
  let unbanUser = $state<ShadowbannedUser | null>(null);
  let unbanOpen = $state(false);
  let submitting = $state(false);

  let canSubmit = $derived(selectedUser !== null && reason.trim().length > 0);

  function submitShadowban() {
    if (!selectedUser) return;

    submitting = true;
    router.post(
      createUrl,
      { user_id: selectedUser.id, reason: reason.trim() },
      {
        onFinish: () => {
          submitting = false;
          confirmBanOpen = false;
          selectedUser = null;
          reason = "";
        },
      },
    );
  }

  function submitUnban() {
    if (!unbanUser) return;

    submitting = true;
    router.delete(destroyUrl, {
      data: { user_id: unbanUser.id },
      onFinish: () => {
        submitting = false;
        unbanUser = null;
        unbanOpen = false;
      },
    });
  }
</script>

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
      testid="shadowban-user"
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
        class="!border-red !bg-red !text-on-primary hover:!opacity-90"
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

    {#if shadowbanned_users.length === 0}
      <div
        class="rounded-lg border border-dashed border-surface-200 py-10 text-center text-sm text-muted"
      >
        No users are currently leaderboard shadowbanned.
      </div>
    {:else}
      <div class="overflow-x-auto rounded-lg border border-surface-200">
        <table class="w-full text-left text-sm">
          <thead
            class="border-b border-surface-200 bg-surface-100/30 text-xs uppercase text-muted"
          >
            <tr>
              <th class="px-4 py-3">User</th>
              <th class="px-4 py-3">Reason</th>
              <th class="px-4 py-3">Updated</th>
              <th class="px-4 py-3 text-right">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-surface-200">
            {#each shadowbanned_users as user}
              <tr>
                <td class="px-4 py-3">
                  <div class="flex items-center gap-3">
                    {#if user.avatar_url}
                      <img
                        src={user.avatar_url}
                        alt=""
                        class="h-9 w-9 rounded-full"
                      />
                    {:else}
                      <div class="h-9 w-9 rounded-full bg-surface-100"></div>
                    {/if}
                    <div>
                      <div class="font-medium text-surface-content">
                        {user.display_name}
                      </div>
                      <div class="text-xs text-muted">
                        ID: {user.id}{user.email ? ` · ${user.email}` : ""}
                      </div>
                    </div>
                  </div>
                </td>
                <td class="max-w-sm px-4 py-3 text-muted">
                  {user.leaderboard_shadowban_reason}
                </td>
                <td class="px-4 py-3 text-muted">{user.updated_at}</td>
                <td class="px-4 py-3 text-right">
                  <Button
                    type="button"
                    variant="surface"
                    onclick={() => {
                      unbanUser = user;
                      unbanOpen = true;
                    }}
                  >
                    Remove
                  </Button>
                </td>
              </tr>
            {/each}
          </tbody>
        </table>
      </div>
    {/if}
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
        {reason}
      </p>
    </div>
  {/snippet}
  {#snippet actions()}
    <div class="flex justify-end gap-3">
      <Button
        type="button"
        variant="surface"
        onclick={() => (confirmBanOpen = false)}
      >
        Cancel
      </Button>
      <Button
        type="button"
        variant="primary"
        class="!border-red !bg-red !text-on-primary hover:!opacity-90"
        disabled={submitting}
        onclick={submitShadowban}
      >
        {submitting ? "Saving..." : "Confirm shadowban"}
      </Button>
    </div>
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
    <div class="flex justify-end gap-3">
      <Button
        type="button"
        variant="surface"
        onclick={() => {
          unbanUser = null;
          unbanOpen = false;
        }}
      >
        Cancel
      </Button>
      <Button
        type="button"
        variant="primary"
        disabled={submitting}
        onclick={submitUnban}
      >
        {submitting ? "Removing..." : "Remove shadowban"}
      </Button>
    </div>
  {/snippet}
</Modal>
