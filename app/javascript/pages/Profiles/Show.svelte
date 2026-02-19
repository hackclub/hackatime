<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import ActivityGraph from "../Home/signedIn/ActivityGraph.svelte";
  import HorizontalBarList from "../Home/signedIn/HorizontalBarList.svelte";

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

  type TotalsData = {
    today_seconds: number;
    week_seconds: number;
    all_seconds: number;
    today_label: string;
    week_label: string;
    all_label: string;
  };

  type ProjectData = {
    project: string;
    duration_seconds: number;
    duration_label: string;
    repo_url?: string | null;
  };

  type StatsData = {
    totals: TotalsData;
    top_projects_month: ProjectData[];
    top_languages: [string, number][];
    top_editors: [string, number][];
    activity_graph: {
      start_date: string;
      end_date: string;
      duration_by_date: Record<string, number>;
      busiest_day_seconds: number;
      timezone_label: string;
      timezone_settings_path: string;
    };
  };

  let {
    page_title,
    profile_visible,
    is_own_profile,
    edit_profile_path,
    profile,
    stats,
  }: {
    page_title: string;
    profile_visible: boolean;
    is_own_profile: boolean;
    edit_profile_path?: string | null;
    profile: ProfileData;
    stats?: StatsData;
  } = $props();

  const hasStats = $derived(Boolean(stats));
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="mx-auto max-w-6xl space-y-6">
  <section
    class="overflow-hidden rounded-2xl border border-surface-200 bg-surface p-6 shadow-sm"
  >
    <div class="flex flex-col gap-6 md:flex-row md:items-start md:justify-between">
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
            <p class="mt-4 whitespace-pre-wrap text-sm leading-6 text-surface-content/90">
              {profile.bio}
            </p>
          {/if}
        </div>
      </div>

      {#if is_own_profile && edit_profile_path}
        <div class="md:pl-4">
          <Button href={edit_profile_path}>Edit Profile</Button>
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
    {#if hasStats && stats}
      <section class="grid grid-cols-1 gap-4 sm:grid-cols-3">
        <div class="rounded-xl border border-primary/60 bg-surface p-4">
          <div class="text-xs uppercase tracking-wide text-muted">Today</div>
          <div class="mt-2 text-2xl font-bold text-primary">{stats.totals.today_label}</div>
        </div>
        <div class="rounded-xl border border-primary/60 bg-surface p-4">
          <div class="text-xs uppercase tracking-wide text-muted">This Week</div>
          <div class="mt-2 text-2xl font-bold text-primary">{stats.totals.week_label}</div>
        </div>
        <div class="rounded-xl border border-primary/60 bg-surface p-4">
          <div class="text-xs uppercase tracking-wide text-muted">All Time</div>
          <div class="mt-2 text-2xl font-bold text-primary">{stats.totals.all_label}</div>
        </div>
      </section>

      <section class="rounded-xl border border-surface-200 bg-surface p-6">
        <div class="mb-4 flex items-end justify-between gap-3">
          <h2 class="text-xl font-semibold text-surface-content">Top Projects</h2>
          <p class="text-sm text-muted">Past month</p>
        </div>

        {#if stats.top_projects_month.length > 0}
          <div class="grid grid-cols-1 gap-3 md:grid-cols-2">
            {#each stats.top_projects_month as project}
              <article class="rounded-lg border border-surface-200 bg-darker p-4">
                <div class="flex items-center justify-between gap-3">
                  <h3 class="truncate font-medium text-surface-content" title={project.project}>
                    {project.project || "Unknown"}
                  </h3>
                  <span class="text-sm font-semibold text-primary">{project.duration_label}</span>
                </div>

                {#if project.repo_url}
                  <a
                    href={project.repo_url}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="mt-2 inline-flex text-xs text-muted underline hover:text-primary"
                  >
                    Open repository
                  </a>
                {/if}
              </article>
            {/each}
          </div>
        {:else}
          <p class="text-sm text-muted">No project activity in the past month.</p>
        {/if}
      </section>

      <section class="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <HorizontalBarList
          title="Top Languages"
          entries={stats.top_languages}
          empty_message="No language activity yet."
        />

        <HorizontalBarList
          title="Favorite Editors"
          entries={stats.top_editors}
          empty_message="No editor activity yet."
        />
      </section>

      <section id="profile_activity" class="rounded-xl border border-surface-200 bg-surface p-6">
        <h2 class="text-xl font-semibold text-surface-content">Activity</h2>
        <ActivityGraph data={stats.activity_graph} />
      </section>
    {:else}
      <section class="rounded-xl border border-surface-200 bg-surface p-6">
        <p class="text-sm text-muted">Loading profile stats...</p>
      </section>
    {/if}
  {:else}
    <section class="rounded-xl border border-yellow/35 bg-yellow/10 p-6 text-center">
      <p class="text-lg font-semibold text-surface-content">Stats are private</p>
      <p class="mt-2 text-sm text-muted">
        This user chose not to share coding stats publicly.
      </p>
      {#if is_own_profile && edit_profile_path}
        <div class="mt-4">
          <Button href={`${edit_profile_path}#user_privacy`} variant="surface">
            Update privacy settings
          </Button>
        </div>
      {/if}
    </section>
  {/if}

  <div class="text-sm text-muted">
    <Link href="/leaderboards" class="underline hover:text-primary">Explore leaderboards</Link>
  </div>
</div>
