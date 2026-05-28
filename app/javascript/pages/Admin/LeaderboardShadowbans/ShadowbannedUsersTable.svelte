<script lang="ts" module>
  import type { UserPickerResult } from "../../../components/UserPicker.svelte";

  export type ShadowbannedUser = UserPickerResult & {
    leaderboard_shadowbanned: boolean;
    leaderboard_shadowban_reason: string | null;
    updated_at: string | null;
  };
</script>

<script lang="ts">
  import Button from "../../../components/Button.svelte";

  let {
    users,
    onRemove,
  }: {
    users: ShadowbannedUser[];
    onRemove: (user: ShadowbannedUser) => void;
  } = $props();
</script>

{#snippet avatar(user: ShadowbannedUser)}
  {#if user.avatar_url}
    <img src={user.avatar_url} alt="" class="h-9 w-9 rounded-full" />
  {:else}
    <div class="h-9 w-9 rounded-full bg-surface-100"></div>
  {/if}
{/snippet}

{#if users.length === 0}
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
          <th class="px-4 py-3" scope="col">User</th>
          <th class="px-4 py-3" scope="col">Reason</th>
          <th class="px-4 py-3" scope="col">Updated</th>
          <th class="px-4 py-3 text-right" scope="col">Action</th>
        </tr>
      </thead>
      <tbody class="divide-y divide-surface-200">
        {#each users as user}
          <tr>
            <td class="px-4 py-3">
              <div class="flex items-center gap-3">
                {@render avatar(user)}
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
                aria-label={`Remove leaderboard shadowban for ${user.display_name}`}
                onclick={() => onRemove(user)}
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
