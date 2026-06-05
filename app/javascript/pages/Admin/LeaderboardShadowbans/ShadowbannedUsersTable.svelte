<script lang="ts" module>
  import type { UserPickerResult } from "../../../components/UserPicker.svelte";

  type AvatarUser = Pick<UserPickerResult, "avatar_url">;

  type ShadowbannedBy = Pick<
    UserPickerResult,
    "id" | "display_name" | "avatar_url" | "username"
  > & {
    admin_level: string;
  };

  export type ShadowbannedUser = UserPickerResult & {
    leaderboard_shadowbanned: boolean;
    leaderboard_shadowban_reason: string | null;
    leaderboard_shadowban_expires_at: string | null;
    leaderboard_shadowban_expires_at_formatted: string | null;
    shadowbanned_by: ShadowbannedBy | null;
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

{#snippet avatar(user: AvatarUser)}
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
  <div class="space-y-3">
    {#each users as user}
      <article class="rounded-xl border border-surface-200 bg-surface/40 p-4">
        <div
          class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between"
        >
          <div class="flex min-w-0 items-center gap-3">
            {@render avatar(user)}
            <div class="min-w-0">
              <h3 class="truncate font-semibold text-surface-content">
                {user.display_name}
              </h3>
              <p class="mt-1 text-sm text-muted [text-wrap:pretty]">
                {user.leaderboard_shadowban_reason || "No reason recorded"}
              </p>
            </div>
          </div>

          <Button
            type="button"
            variant="surface"
            size="sm"
            class="shrink-0 self-start"
            aria-label={`Remove leaderboard shadowban for ${user.display_name}`}
            onclick={() => onRemove(user)}
          >
            Remove
          </Button>
        </div>

        <dl class="mt-4 grid gap-3 text-sm sm:grid-cols-3">
          <div class="rounded-lg bg-surface-100/40 px-3 py-2">
            <dt class="text-xs font-semibold tracking-wide text-muted">
              Auto-remove
            </dt>
            <dd class="mt-1 text-surface-content tabular-nums">
              {user.leaderboard_shadowban_expires_at_formatted ?? "Never"}
            </dd>
          </div>

          <div class="rounded-lg bg-surface-100/40 px-3 py-2">
            <dt class="text-xs font-semibold tracking-wide text-muted">
              Added by
            </dt>
            <dd
              class="mt-1 flex min-w-0 items-center gap-2 text-surface-content"
            >
              {#if user.shadowbanned_by}
                {#if user.shadowbanned_by.avatar_url}
                  <img
                    src={user.shadowbanned_by.avatar_url}
                    alt=""
                    class="h-6 w-6 shrink-0 rounded-full"
                  />
                {:else}
                  <div
                    class="h-6 w-6 shrink-0 rounded-full bg-surface-200"
                  ></div>
                {/if}
                <span class="truncate">{user.shadowbanned_by.display_name}</span
                >
              {:else}
                Unknown
              {/if}
            </dd>
          </div>

          <div class="rounded-lg bg-surface-100/40 px-3 py-2">
            <dt class="text-xs font-semibold tracking-wide text-muted">
              Updated
            </dt>
            <dd class="mt-1 text-surface-content tabular-nums">
              {user.updated_at ?? "Unknown"}
            </dd>
          </div>
        </dl>
      </article>
    {/each}
  </div>
{/if}
