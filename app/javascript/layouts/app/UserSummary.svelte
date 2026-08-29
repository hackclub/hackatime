<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import CountryFlag from "../../components/CountryFlag.svelte";
  import { profiles } from "../../api";
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
  const profilePath = $derived(
    user.username ? profiles.show.path({ username: user.username }) : null,
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
  {#if profilePath}
    <Link
      href={profilePath}
      aria-label={`View ${user.display_name}'s profile`}
      class="group inline-grid w-fit max-w-full items-center gap-1"
    >
      <span
        class="col-start-1 row-start-1 truncate transition-all duration-200 group-hover:opacity-0 group-hover:-translate-y-1"
      >
        {user.display_name}
      </span>
      <span
        class="col-start-1 row-start-1 truncate text-muted opacity-0 translate-y-1 transition-all duration-200 group-hover:opacity-100 group-hover:translate-y-0"
      >
        @{user.username}
      </span>
    </Link>
  {:else}
    <span class="inline-flex max-w-full items-center gap-1 truncate">
      {user.display_name}
    </span>
  {/if}
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
