<script lang="ts">
  import CountryFlag from "../../components/CountryFlag.svelte";
  import StreakIcon from "./StreakIcon.svelte";
  import { streakTheme, streakLabel } from "../../utils";
  import type { AdminLevel, NavCurrentUser } from "../../types";

  let { user }: { user: NavCurrentUser } = $props();

  const adminLevelMeta: Partial<
    Record<AdminLevel, { label: string; class: string }>
  > = {
    ultraadmin: {
      label: "Ultraadmin",
      class: "text-purple-400 ultraadmin-tool",
    },
    superadmin: { label: "Superadmin", class: "text-red superadmin-tool" },
    admin: { label: "Admin", class: "text-yellow admin-tool" },
    viewer: { label: "Viewer", class: "text-blue viewer-tool" },
  };

  const adminMeta = $derived(
    user.admin_level ? adminLevelMeta[user.admin_level] : null,
  );
  const streak = $derived(
    user.streak_days ? streakTheme(user.streak_days) : null,
  );
</script>

<div class="user-info flex min-h-10 items-center gap-2" title={user.title}>
  {#if user.avatar_url}
    <img
      src={user.avatar_url}
      alt={`${user.display_name}'s avatar`}
      width="32"
      height="32"
      class="avatar-image-outline aspect-square rounded-full"
      loading="lazy"
    />
  {/if}
  <span class="inline-flex items-center gap-1">{user.display_name}</span>
  {#if user.country_code}
    <span
      class="flex items-center"
      title={user.country_name || user.country_code}
    >
      <CountryFlag
        countryCode={user.country_code}
        countryName={user.country_name}
      />
    </span>
  {/if}
</div>

{#if streak && user.streak_days}
  <div
    class={`group inline-flex items-center gap-1 rounded-lg bg-gradient-to-r px-2 py-1 transition-[background-color,border-color,color,box-shadow] duration-200 ${streak.bg} border ${streak.bc} ${streak.hbg}`}
    title={user.streak_days > 30
      ? "30+ daily streak"
      : `${user.streak_days} day streak`}
  >
    <StreakIcon
      class={`${streak.ic} transition-colors duration-200 group-hover:animate-pulse`}
    />
    <span
      class={`text-md font-semibold tabular-nums ${streak.tc} transition-colors duration-200`}
    >
      {streakLabel(user.streak_days)}
      <span class={`ml-1 font-normal ${streak.tm}`}>day streak</span>
    </span>
  </div>
{/if}

{#if adminMeta}
  <span class={`${adminMeta.class} font-semibold px-2`}>{adminMeta.label}</span>
{/if}
