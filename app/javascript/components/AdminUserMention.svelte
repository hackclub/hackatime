<script lang="ts">
  import { sessions } from "../api";

  type User = {
    id: number;
    display_name: string;
    avatar_url: string | null;
    can_impersonate: boolean;
  };

  let { user }: { user: User } = $props();
</script>

<div class="flex items-center gap-2">
  {#if user.avatar_url}
    <img
      src={user.avatar_url}
      alt={`${user.display_name}'s avatar`}
      class="h-8 w-8 rounded-full border border-surface-200"
    />
  {/if}
  <span>{user.display_name}</span>
  {#if user.can_impersonate}
    <a
      href={sessions.impersonate.path({ id: user.id })}
      aria-label={`Impersonate ${user.display_name}`}
      title={`Impersonate ${user.display_name}`}
      class="font-bold text-primary transition-colors duration-200 hover:text-red"
      >🥸</a
    >
  {/if}
</div>
