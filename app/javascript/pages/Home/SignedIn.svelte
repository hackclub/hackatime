<script lang="ts">
  import { Deferred } from "@inertiajs/svelte";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentence from "./signedIn/TodaySentence.svelte";
  import MiniLeaderboardSkeleton from "./signedIn/MiniLeaderboardSkeleton.svelte";
  import DashboardSkeleton from "./signedIn/DashboardSkeleton.svelte";
  import Dashboard from "./signedIn/Dashboard.svelte";
  import ActivityGraphSkeleton from "./signedIn/ActivityGraphSkeleton.svelte";

  type SocialProofUser = { display_name: string; avatar_url: string };

  let {
    flavor_text,
    trust_level_red,
    show_wakatime_setup_notice,
    ssp_message,
    ssp_users_recent,
    ssp_users_size,
    github_uid_blank,
    github_auth_path,
    wakatime_setup_path,
    show_logged_time_sentence,
    todays_duration_display,
    todays_languages,
    todays_editors,
    mini_leaderboard_html,
    filterable_dashboard_data,
    activity_graph_html,
  }: {
    flavor_text: string;
    trust_level_red: boolean;
    show_wakatime_setup_notice: boolean;
    ssp_message?: string | null;
    ssp_users_recent: SocialProofUser[];
    ssp_users_size: number;
    github_uid_blank: boolean;
    github_auth_path: string;
    wakatime_setup_path: string;
    show_logged_time_sentence: boolean;
    todays_duration_display: string;
    todays_languages: string[];
    todays_editors: string[];
    mini_leaderboard_html?: string | null;
    filterable_dashboard_data?: Record<string, any> | null;
    activity_graph_html?: string | null;
  } = $props();
</script>

<div class="container">
  <div class="flex items-center space-x-2 mt-2">
    <p class="italic text-gray-400 m-0">
      {@html flavor_text}
    </p>
  </div>

  <h1 class="font-bold mt-1 mb-4 text-5xl text-center">
    Keep Track of <span class="text-primary">Your</span> Coding Time
  </h1>

  {#if true}
    <BanNotice />
  {/if}

  {#if show_wakatime_setup_notice}
    <SetupNotice
      {wakatime_setup_path}
      {ssp_message}
      {ssp_users_recent}
      {ssp_users_size}
    />
  {/if}

  {#if github_uid_blank}
    <GitHubLinkBanner {github_auth_path} />
  {/if}

  <TodaySentence
    {show_logged_time_sentence}
    {todays_duration_display}
    {todays_languages}
    {todays_editors}
  />

  <div id="mini_leaderboard">
    <Deferred data="mini_leaderboard_html">
      {#snippet fallback()}
        <MiniLeaderboardSkeleton />
      {/snippet}
      {@html mini_leaderboard_html ?? ""}
    </Deferred>
  </div>

  <div id="filterable_dashboard">
    <Deferred data="filterable_dashboard_data">
      {#snippet fallback()}
        <DashboardSkeleton />
      {/snippet}
      {#if filterable_dashboard_data}
        <Dashboard data={filterable_dashboard_data} />
      {/if}
    </Deferred>
  </div>

  <div id="activity_graph">
    <Deferred data="activity_graph_html">
      {#snippet fallback()}
        <ActivityGraphSkeleton />
      {/snippet}
      {@html activity_graph_html ?? ""}
    </Deferred>
  </div>
</div>
