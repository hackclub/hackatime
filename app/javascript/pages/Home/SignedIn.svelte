<script lang="ts">
  import type InertiaHomeSignedInProps from "../../types/serializers/Inertia/HomeSignedInProps";
  import BanNotice from "./signedIn/BanNotice.svelte";
  import GitHubLinkBanner from "./signedIn/GitHubLinkBanner.svelte";
  import SetupNotice from "./signedIn/SetupNotice.svelte";
  import TodaySentence from "./signedIn/TodaySentence.svelte";
  import Dashboard from "./signedIn/Dashboard.svelte";
  import ActivityGraph from "./signedIn/ActivityGraph.svelte";

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
    filterable_dashboard_data,
    activity_graph,
  }: InertiaHomeSignedInProps = $props();
</script>

<div>
  <!-- Header Section -->
  <div class="mb-8">
    <div class="flex items-center space-x-2">
      <p class="italic text-gray-400 m-0">
        {@html flavor_text}
      </p>
    </div>

    <h1 class="font-bold mt-2 mb-4 text-3xl md:text-4xl">
      Keep Track of <span class="text-primary">Your</span> Coding Time
    </h1>
  </div>

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

  <div class="flex flex-col gap-8">
    <!-- Today Stats & Leaderboard -->
    <div>
      <TodaySentence
        {show_logged_time_sentence}
        {todays_duration_display}
        {todays_languages}
        {todays_editors}
      />
    </div>

    <!-- Main Dashboard -->
    <Dashboard data={filterable_dashboard_data} />

    <!-- Activity Graph -->
    <ActivityGraph data={activity_graph} />
  </div>
</div>
