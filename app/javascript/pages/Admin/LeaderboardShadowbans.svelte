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

  type Pending = { kind: "ban" } | { kind: "unban"; user: ShadowbannedUser };

  let selectedUser = $state<UserPickerResult | null>(null);
  let reason = $state("");
  let pending = $state<Pending | null>(null);
  let submitting = $state(false);

  let trimmedReason = $derived(reason.trim());
  let canSubmit = $derived(selectedUser !== null && trimmedReason.length > 0);

  function submit() {
    if (!pending || submitting) return;
    submitting = true;

    const onFinish = () => {
      submitting = false;
      if (pending?.kind === "ban") {
        selectedUser = null;
        reason = "";
      }
      pending = null;
    };

    if (pending.kind === "ban" && selectedUser) {
      router.post(
        createUrl,
        { user_id: selectedUser.id, reason: trimmedReason },
        { onFinish },
      );
    } else if (pending.kind === "unban") {
      router.delete(
        adminLeaderboardShadowbans.destroy.path({ user_id: pending.user.id }),
        { onFinish },
      );
    }
  }
</script>

<svelte:head>
  <title>Leaderboard Shadowbans</title>
</svelte:head>

<div class="mx-auto max-w-5xl space-y-6">
  <header class="text-center">
    <h1 class="text-4xl font-bold text-surface-content">
      Leaderboard Shadowbans
    </h1>
    <p class="mt-2 text-muted">hide users from the leaderboards!</p>
  </header>

  <section class="rounded-xl border border-primary bg-dark p-6">
    <h2 class="mb-4 text-xl font-semibold text-surface-content">
      Add a shadowban
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
        onclick={() => (pending = { kind: "ban" })}
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
      onRemove={(user) => (pending = { kind: "unban", user })}
    />
  </section>
</div>

<Modal
  bind:open={
    () => pending !== null,
    (v) => {
      if (!v) pending = null;
    }
  }
  title={pending?.kind === "unban"
    ? "Remove leaderboard shadowban?"
    : "Confirm leaderboard shadowban"}
  description={pending?.kind === "unban"
    ? "This user will become visible to other leaderboard viewers again."
    : "No one else will see this user on the public leaderboards."}
  maxWidth="max-w-lg"
  hasActions
>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={() => (pending = null)}>Go back</Button
      >

      <Button
        type="button"
        variant="primary"
        class="h-10 w-full text-on-primary {pending?.kind === 'unban'
          ? ''
          : redButtonClass}"
        disabled={submitting}
        onclick={submit}
      >
        {#if submitting}
          {pending?.kind === "unban" ? "Removing..." : "Saving..."}
        {:else}
          {pending?.kind === "unban" ? "Remove shadowban" : "Confirm shadowban"}
        {/if}
      </Button>
    </div>
  {/snippet}
</Modal>
