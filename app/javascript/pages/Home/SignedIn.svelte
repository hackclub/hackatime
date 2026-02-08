<script lang="ts">
  import type {
    MiniLeaderboardData,
    ActivityGraphData,
  } from "../../types/index";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentence from "./signedIn/TodaySentence.svelte";
  import MiniLeaderboard from "./signedIn/MiniLeaderboard.svelte";
  import Dashboard from "./signedIn/Dashboard.svelte";
  import ActivityGraph from "./signedIn/ActivityGraph.svelte";

  type SocialProofUser = { display_name: string; avatar_url: string };

  type FilterableDashboardData = {
    total_time: number;
    total_heartbeats: number;
    top_project: string | null;
    top_language: string | null;
    top_editor: string | null;
    top_operating_system: string | null;
    project_durations: Record<string, number>;
    language_stats: Record<string, number>;
    editor_stats: Record<string, number>;
    operating_system_stats: Record<string, number>;
    category_stats: Record<string, number>;
    weekly_project_stats: Record<string, Record<string, number>>;
    project: string[];
    language: string[];
    editor: string[];
    operating_system: string[];
    category: string[];
    selected_interval: string;
    selected_from: string;
    selected_to: string;
    selected_project: string[];
    selected_language: string[];
    selected_editor: string[];
    selected_operating_system: string[];
    selected_category: string[];
  };

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
    mini_leaderboard,
    filterable_dashboard_data,
    activity_graph,
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
    mini_leaderboard: MiniLeaderboardData;
    filterable_dashboard_data: FilterableDashboardData;
    activity_graph: ActivityGraphData;
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

  {#if trust_level_red}
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

  <MiniLeaderboard data={mini_leaderboard} />
  <Dashboard data={filterable_dashboard_data} />
  <ActivityGraph data={activity_graph} />
</div>
