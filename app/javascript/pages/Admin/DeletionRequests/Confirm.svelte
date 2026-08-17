<script lang="ts">
  import { Form, Link } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import TextInput from "../../../components/TextInput.svelte";
  import { adminDeletionRequests } from "../../../api";
  type User = {
    id: number;
    display_name: string;
    avatar_url: string;
    username: string | null;
    trust_level: string;
    email: string;
    joined_at: string;
    active_deletion_request: boolean;
  };
  let { user }: { user: User } = $props();
  const trust: Record<string, string> = {
    green: "bg-green/20 text-green",
    yellow: "bg-yellow/20 text-yellow",
    red: "bg-red/20 text-red",
  };
</script>

<svelte:head><title>confirm deletion</title></svelte:head>
<div class="max-w-lg mx-auto p-6 space-y-6">
  <header class="text-center mb-8">
    <h1 class="text-4xl font-bold text-surface-content mb-2">
      confirm deletion
    </h1>
  </header>
  <div class="border border-surface-200 rounded-xl p-6 bg-dark space-y-3">
    <div class="flex items-center gap-4">
      <img src={user.avatar_url} alt="Avatar" class="w-14 h-14 rounded-full" />
      <div>
        <p class="text-surface-content font-semibold text-lg">
          {user.display_name}
        </p>
        <p class="text-muted text-sm">@{user.username} · #{user.id}</p>
      </div>
      <span
        class="ml-auto px-2 py-1 rounded text-xs font-medium {trust[
          user.trust_level
        ] || 'bg-blue/20 text-blue'}">{user.trust_level}</span
      >
    </div>
    <div class="text-sm text-muted space-y-1 pt-2 border-t border-surface-200">
      <p>email: {user.email}</p>
      <p>joined: {user.joined_at}</p>
      {#if user.active_deletion_request}<p class="text-yellow">
          already has an active deletion request
        </p>{/if}
    </div>
  </div>
  <div class="border border-primary rounded-xl p-6 bg-dark">
    <Form action={adminDeletionRequests.create.path()} method="post"
      ><input type="hidden" name="deletion_request[user_id]" value={user.id} />
      <div class="space-y-4">
        <div class="border border-red/40 rounded-lg p-4 bg-red/5">
          <label class="flex items-start gap-3 cursor-pointer"
            ><input
              type="checkbox"
              name="deletion_request[instant]"
              value="1"
              class="mt-0.5 accent-red shrink-0"
            />
            <div>
              <span class="text-red font-medium text-sm">instant deletion</span>
              <p class="text-muted text-xs mt-0.5">
                skips the 30-day grace period. approves, sets deletion to now,
                and enqueues the job immediately. cannot be undone.
              </p>
            </div></label
          >
        </div>
        <div>
          <label for="confirm" class="block text-sm text-muted mb-1"
            >type <span class="text-surface-content font-mono"
              >{user.username || "DELETE"}</span
            > to confirm</label
          ><TextInput
            id="confirm"
            name="deletion_request[confirm_username]"
            autocomplete="off"
            class="w-full bg-surface border border-surface-200 rounded-lg px-3 py-2 text-surface-content focus:outline-none focus:border-red font-mono"
          />
        </div>
        <Button
          type="submit"
          class="w-full px-4 py-2 bg-red hover:bg-red text-on-primary font-medium rounded-lg transition-colors"
          >create deletion request</Button
        >
      </div></Form
    >
  </div>
  <div class="text-center">
    <Link
      href={adminDeletionRequests.new.path()}
      class="text-sm text-muted hover:text-surface-content">back to lookup</Link
    >
  </div>
</div>
