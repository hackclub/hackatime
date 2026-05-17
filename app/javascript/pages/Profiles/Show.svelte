<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import ActivityGraph from "../Home/signedIn/ActivityGraph.svelte";
  import Dashboard from "../Home/signedIn/Dashboard.svelte";
  import { settingsProfile } from "../../api";
  import type {
    ActivityGraphData,
    FilterableDashboardData,
  } from "../../types/index";

  type SocialLink = {
    key: string;
    label: string;
    url: string;
  };

  type ProfileData = {
    display_name: string;
    username: string;
    avatar_url: string;
    trust_level: string;
    bio?: string | null;
    social_links: SocialLink[];
    github_profile_url?: string | null;
    github_username?: string | null;
    streak_days?: number | null;
  };

  type DashboardStats = {
    filterable_dashboard_data: Partial<FilterableDashboardData>;
    activity_graph: ActivityGraphData;
  };

  let {
    page_title,
    profile_visible,
    is_own_profile,
    profile,
    dashboard_stats,
  }: {
    page_title: string;
    profile_visible: boolean;
    is_own_profile: boolean;
    profile: ProfileData;
    dashboard_stats?: DashboardStats;
  } = $props();

  const editProfilePath = settingsProfile.my.path();
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6">
  <section
    class="overflow-hidden rounded-2xl border border-surface-200 bg-surface p-6 shadow-sm"
  >
    <div
      class="flex flex-col gap-6 md:flex-row md:items-start md:justify-between"
    >
      <div class="flex min-w-0 items-start gap-4">
        <img
          src={profile.avatar_url}
          alt={profile.display_name}
          class="h-20 w-20 shrink-0 rounded-full border-2 border-primary object-cover"
        />
        <div class="min-w-0">
          <div class="flex flex-wrap items-center gap-2">
            <h1 class="truncate text-3xl font-bold text-surface-content">
              {profile.display_name}
            </h1>
            {#if profile.trust_level === "green"}
              <span
                class="inline-flex items-center rounded-full bg-primary/15 px-2 py-1 text-xs font-semibold text-primary"
              >
                Verified
              </span>
            {/if}
            {#if profile.streak_days && profile.streak_days > 0}
              <span
                class="inline-flex items-center rounded-full bg-orange-500/15 px-2 py-1 text-xs font-semibold text-orange-300"
              >
                Streak: {profile.streak_days} days
              </span>
            {/if}
          </div>

          <p class="mt-1 text-sm text-muted">@{profile.username}</p>

          {#if profile.bio}
            <p
              class="mt-4 whitespace-pre-wrap text-sm leading-6 text-surface-content/90"
            >
              {profile.bio}
            </p>
          {/if}
        </div>
      </div>

      {#if is_own_profile}
        <div class="md:pl-4">
          <Button href={editProfilePath}>Edit Profile</Button>
        </div>
      {/if}
    </div>

    {#if profile.social_links.length > 0}
      <div class="mt-6 flex flex-wrap gap-2">
        {#each profile.social_links as link}
          <a
            href={link.url}
            target="_blank"
            rel="noopener noreferrer"
            class="inline-flex items-center rounded-full border border-surface-200 bg-darker px-3 py-1.5 text-sm text-surface-content transition-colors hover:border-primary hover:text-primary"
          >
            {link.label}
          </a>
        {/each}
      </div>
    {/if}
  </section>

  {#if profile_visible}
    {#if dashboard_stats}
      <Dashboard
        data={dashboard_stats.filterable_dashboard_data}
        showFilters={false}
      />

      <section
        id="profile_activity"
        class="rounded-xl border border-surface-200 bg-surface p-6"
      >
        <h2 class="text-xl font-semibold text-surface-content">Activity</h2>
        <ActivityGraph data={dashboard_stats.activity_graph} />
      </section>
    {:else}
      <section class="rounded-xl border border-surface-200 bg-surface p-6">
        <p class="text-sm text-muted">Loading profile stats...</p>
      </section>
    {/if}
  {:else}
    <section
      class="rounded-xl border border-yellow/35 bg-yellow/10 p-6 text-center"
    >
      <p class="text-lg font-semibold text-surface-content">
        Stats are private
      </p>
      <p class="mt-2 text-sm text-muted">
        This user chose not to share coding stats publicly.
      </p>
      {#if is_own_profile}
        <div class="mt-4">
          <Button href={`${editProfilePath}#user_privacy`} variant="surface">
            Update privacy settings
          </Button>
        </div>
      {/if}
    </section>
  {/if}

  <div class="text-sm text-muted">
    <Link href="/leaderboards" class="underline hover:text-primary"
      >Explore leaderboards</Link
    >
  </div>
</div>
