<script lang="ts">
  import { Deferred } from "@inertiajs/svelte";

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

  const miniLeaderboardRows = Array.from({ length: 6 });
  const filterRows = Array.from({ length: 6 });
  const statCards = Array.from({ length: 6 });
  const barRows = Array.from({ length: 10 });
  const barHeights = Array.from(
    { length: 12 },
    () => Math.floor(Math.random() * 81) + 20,
  );
  const activitySquares = Array.from({ length: 365 });

  const pluralize = (count: number, singular: string, plural: string) =>
    count === 1 ? singular : plural;

  const toSentence = (items: string[]) => {
    if (items.length === 0) return "";
    if (items.length === 1) return items[0];
    if (items.length === 2) return `${items[0]} and ${items[1]}`;
    return `${items.slice(0, -1).join(", ")}, and ${items[items.length - 1]}`;
  };

  const secondsToDisplay = (seconds?: number) => {
    if (!seconds) return "0m";
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    return hours > 0 ? `${hours}h ${minutes}m` : `${minutes}m`;
  };

  const percentOf = (value: number, max: number) => {
    if (!max || max === 0) return 0;
    return Math.max(2, Math.round((value / max) * 100));
  };
</script>

<div class="container">
  {#if trust_level_red}
    <div
      class="text-primary bg-red-500/10 border-2 border-red-500/20 p-4 text-center rounded-lg mb-4"
    >
      <div class="flex items-center justify-center">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 16 16"
          ><path
            fill="currentColor"
            fill-rule="evenodd"
            d="M8 14.5a6.5 6.5 0 1 0 0-13a6.5 6.5 0 0 0 0 13M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16m1-5a1 1 0 1 1-2 0a1 1 0 0 1 2 0m-.25-6.25a.75.75 0 0 0-1.5 0v3.5a.75.75 0 0 0 1.5 0z"
            clip-rule="evenodd"
          /></svg
        >
        <span class="text-3xl font-bold block ml-2"
          >Hold up! Your account has been banned for suspicious activity.</span
        >
      </div>
      <div>
        <p class="text-primary text-left text-lg mb-2">
          <b>What does this mean?</b> Your account was convicted for fraud or abuse
          of Hackatime, such as using methods to gain an unfair advantage on the
          leaderboards or attempting to manipulate your coding time in any way. This
          restricts your access to participate in public leaderboards, but Hackatime
          will still track and display your time. This may also affect your ability
          to participate in current and future Hack Club events.
        </p>
        <p class="text-primary text-left text-lg mb-2">
          <b>What can I do?</b> Account bans are non-negotiable, and will not be
          removed unless determined to have been issued incorrectly. In that
          case, it will automatically be removed. We take fraud very seriously
          and have a zero-tolerance policy for abuse. If you believe this was a
          mistake, please DM the
          <a
            href="https://hackclub.slack.com/team/U091HC53CE8"
            target="_blank"
            class="underline">Fraud Department</a
          > on Slack. We do not respond in any other channel, DM or thread.
        </p>
        <p class="text-primary text-left text-lg mb-0">
          <b>Can I know what caused this?</b> No. We do not disclose the patterns
          that were detected. Releasing this information would only benefit fraudsters.
          The fraud team regularly investigates claims of false bans to increase
          the effectiveness of our detection systems to combat fraud.
        </p>
      </div>
    </div>
  {/if}
  <div class="flex items-center space-x-2 mt-2">
    <p class="italic text-gray-400 m-0">
      {flavor_text}
    </p>
  </div>
  <div id="clock" class="clockicons clock-display"></div>
  <h1 class="font-bold mt-1 mb-4 text-5xl text-center">
    Keep Track of <span class="text-primary">Your</span> Coding Time
  </h1>

  {#if show_wakatime_setup_notice}
    <div class="text-left my-8 flex flex-col">
      <p class="mb-4 text-xl text-primary">
        Hello friend! Looks like you are new around here, let's get you set up
        so you can start tracking your coding time.
      </p>
      <a
        href={wakatime_setup_path}
        class="inline-block w-auto text-3xl font-bold px-8 py-4 bg-primary text-white rounded shadow-md hover:shadow-lg hover:-translate-y-1 transition-all duration-300 animate-pulse"
        >Let's setup Hackatime! Click me :D</a
      >
      <div class="flex items-center mt-4 flex-nowrap">
        {#if ssp_users_recent.length > 0}
          <div class="flex m-0 ml-0 shrink-0">
            {#each ssp_users_recent as user, index}
              <div
                class={`relative cursor-pointer transition-transform duration-200 hover:-translate-y-1 hover:z-10 group ${index > 0 ? "-ml-4" : ""}`}
              >
                <div
                  class="absolute -top-9 left-1/2 transform -translate-x-1/2 bg-gray-800 text-white px-2 py-1 rounded text-xs whitespace-nowrap opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200 z-20"
                >
                  {user.display_name}
                  <div
                    class="absolute top-full left-1/2 -ml-1 border-l-2 border-r-2 border-t-2 border-transparent border-t-gray-800"
                  ></div>
                </div>
                <img
                  src={user.avatar_url}
                  alt={user.display_name}
                  class="w-10 h-10 rounded-full border-2 border-primary object-cover shadow-sm"
                />
              </div>
            {/each}
            {#if ssp_users_size > 5}
              <div
                class="relative cursor-pointer transition-transform duration-200 hover:-translate-y-1 hover:z-10 group -ml-4"
                title={`See all ${ssp_users_size} users`}
              >
                <div
                  class="w-10 h-10 rounded-full border-2 border-primary bg-primary text-white font-bold text-sm flex items-center justify-center shadow-sm"
                >
                  +{ssp_users_size - 5}
                </div>
                <div
                  class="absolute -left-5 top-11 bg-gray-800 rounded-lg shadow-xl p-4 w-80 z-50 max-h-96 overflow-y-auto opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200"
                >
                  <h4
                    class="mt-0 mb-2 text-base text-gray-200 border-b border-gray-600 pb-2"
                  >
                    All users who set up Hackatime
                  </h4>
                  <div class="flex flex-col gap-2">
                    {#each ssp_users_recent as user}
                      <div
                        class="flex items-center p-1 rounded hover:bg-gray-700 transition-colors duration-200"
                      >
                        <img
                          src={user.avatar_url}
                          alt={user.display_name}
                          class="w-8 h-8 rounded-full mr-2 border border-primary"
                        />
                        <span class="font-medium text-sm"
                          >{user.display_name}</span
                        >
                      </div>
                    {/each}
                  </div>
                  <div
                    class="absolute -top-2 left-8 w-0 h-0 border-l-2 border-r-2 border-b-2 border-transparent border-b-gray-800"
                  ></div>
                </div>
              </div>
            {/if}
          </div>
        {/if}
        {#if ssp_message}
          <p class="m-0 ml-2 italic text-gray-400">
            {ssp_message} (this is real data)
          </p>
        {/if}
      </div>
    </div>
  {/if}

  {#if github_uid_blank}
    <div class="bg-dark border border-primary rounded-lg p-4 mb-6">
      <div class="flex items-center gap-3">
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="24"
          height="24"
          viewBox="0 0 24 24"
          class="text-white shrink-0"
          ><path
            fill="currentColor"
            d="M12 2A10 10 0 0 0 2 12c0 4.42 2.87 8.17 6.84 9.5c.5.08.66-.23.66-.5v-1.69c-2.77.6-3.36-1.34-3.36-1.34c-.46-1.16-1.11-1.47-1.11-1.47c-.91-.62.07-.6.07-.6c1 .07 1.53 1.03 1.53 1.03c.87 1.52 2.34 1.07 2.91.83c.09-.65.35-1.09.63-1.34c-2.22-.25-4.55-1.11-4.55-4.92c0-1.11.38-2 1.03-2.71c-.1-.25-.45-1.29.1-2.64c0 0 .84-.27 2.75 1.02c.79-.22 1.65-.33 2.5-.33s1.71.11 2.5.33c1.91-1.29 2.75-1.02 2.75-1.02c.55 1.35.2 2.39.1 2.64c.65.71 1.03 1.6 1.03 2.71c0 3.82-2.34 4.66-4.57 4.91c.36.31.69.92.69 1.85V21c0 .27.16.59.67.5C19.14 20.16 22 16.42 22 12A10 10 0 0 0 12 2"
          /></svg
        >
        <div class="flex-1">
          <span class="text-white"
            >Link your GitHub account to unlock project linking, show what
            you're working on, and qualify for leaderboards!</span
          >
        </div>
        <a
          href={github_auth_path}
          class="bg-primary hover:bg-primary text-white font-medium px-4 py-2 rounded-lg transition-colors duration-200 shrink-0"
          data-turbo="false">Connect GitHub</a
        >
      </div>
    </div>
  {/if}

  <p class="mt-2">
    {#if show_logged_time_sentence}
      You've logged
      {todays_duration_display}
      {#if todays_languages.length > 0 || todays_editors.length > 0}
        across
        {#if todays_languages.length > 0}
          {#if todays_languages.length >= 4}
            {todays_languages.slice(0, 2).join(", ")}
            <span title={todays_languages.slice(2).join(", ")}>
              (& {todays_languages.length - 2}
              {pluralize(
                todays_languages.length - 2,
                "other language",
                "other languages",
              )})
            </span>
          {:else}
            {toSentence(todays_languages)}
          {/if}
        {/if}
        {#if todays_languages.length > 0 && todays_editors.length > 0}
          using
        {/if}
        {#if todays_editors.length > 0}
          {toSentence(todays_editors)}
        {/if}
      {/if}
    {:else}
      No time logged today... but you can change that!
    {/if}
  </p>

  <div id="mini_leaderboard">
    <Deferred data="mini_leaderboard_html">
      {#snippet fallback()}
        <div class="bg-elevated rounded-xl border border-primary p-4 shadow-lg">
          <p class="text-xs italic text-muted mb-4">
            This leaderboard shows time logged in the last 24 hours (UTC time).
          </p>
          <div class="space-y-2">
            {#each miniLeaderboardRows as _}
              <div
                class="flex items-center p-3 rounded-lg bg-dark animate-pulse"
              >
                <div class="w-8 text-center">
                  <div class="h-5 w-5 bg-darkless rounded mx-auto"></div>
                </div>
                <div class="flex-1 mx-3 min-w-0">
                  <div class="flex items-center gap-2">
                    <div
                      class="w-8 h-8 bg-darkless rounded-full shrink-0"
                    ></div>
                    <div class="h-4 w-24 bg-darkless rounded"></div>
                  </div>
                </div>
                <div class="shrink-0">
                  <div class="h-4 w-16 bg-darkless rounded"></div>
                </div>
              </div>
            {/each}
          </div>
          <div class="mt-4 text-right">
            <div
              class="h-4 w-32 bg-darkless rounded inline-block animate-pulse"
            ></div>
          </div>
        </div>
      {/snippet}
      {@html mini_leaderboard_html ?? ""}
    </Deferred>
  </div>

  <div id="filterable_dashboard">
    <Deferred data="filterable_dashboard_data">
      {#snippet fallback()}
        <div class="max-w-6xl mx-auto my-0 animate-pulse">
          <div class="flex gap-4 mt-2 mb-6 flex-wrap">
            {#each filterRows as _}
              <div class="filter flex-1 min-w-37.5 relative">
                <div class="h-3 w-16 bg-darkless rounded mb-1.5"></div>
                <div class="h-10 w-full bg-darkless rounded-lg"></div>
              </div>
            {/each}
          </div>
        </div>
      {/snippet}
      {#if filterable_dashboard_data}
        {@const dash = filterable_dashboard_data}
        {@const langEntries = Object.entries(dash.language_stats || {})}
        {@const langMax = Math.max(
          ...langEntries.map(([_, v]) => (v as number) || 0),
          1,
        )}
        {@const editorEntries = Object.entries(dash.editor_stats || {})}
        {@const editorMax = Math.max(
          ...editorEntries.map(([_, v]) => (v as number) || 0),
          1,
        )}
        {@const osEntries = Object.entries(dash.operating_system_stats || {})}
        {@const osMax = Math.max(
          ...osEntries.map(([_, v]) => (v as number) || 0),
          1,
        )}
        {@const timelineEntries = Object.entries(
          dash.weekly_project_stats || {},
        )}
        <div class="flex flex-col gap-6 w-full">
          <div
            class="grid grid-cols-[repeat(auto-fill,minmax(9.375rem,1fr))] gap-4"
          >
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Total Time
              </div>
              <div class="text-2xl font-semibold text-white">
                {secondsToDisplay(dash.total_time)}
              </div>
            </div>
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Top Project
              </div>
              <div class="text-lg font-semibold text-white">
                {dash.top_project || "—"}
              </div>
            </div>
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Top Language
              </div>
              <div class="text-lg font-semibold text-white">
                {dash.top_language || "—"}
              </div>
            </div>
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Top Editor
              </div>
              <div class="text-lg font-semibold text-white">
                {dash.top_editor || "—"}
              </div>
            </div>
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Top OS
              </div>
              <div class="text-lg font-semibold text-white">
                {dash.top_operating_system || "—"}
              </div>
            </div>
            <div class="bg-dark border border-primary rounded-xl p-4">
              <div class="text-secondary text-xs mb-1 uppercase tracking-tight">
                Heartbeats
              </div>
              <div class="text-2xl font-semibold text-white">
                {dash.total_heartbeats || 0}
              </div>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 w-full">
            <div
              class="bg-dark border border-primary rounded-xl p-6 flex flex-col"
            >
              <h3 class="text-xl font-semibold mb-4">Project Durations</h3>
              {#if dash.project_durations}
                {@const entries = Object.entries(dash.project_durations)}
                {@const maxVal = Math.max(
                  ...entries.map(([_, v]) => (v as number) || 0),
                  1,
                )}
                <div class="space-y-3">
                  {#each entries as [project, seconds]}
                    <div class="flex items-center gap-3">
                      <div
                        class="w-1/3 truncate font-medium text-white"
                        title={project}
                      >
                        {project}
                      </div>
                      <div
                        class="flex-1 bg-darkless rounded h-3 overflow-hidden"
                      >
                        <div
                          class="h-3 bg-primary rounded"
                          style={`width:${percentOf(seconds as number, maxVal)}%`}
                        ></div>
                      </div>
                      <div class="w-16 text-sm text-muted text-right">
                        {secondsToDisplay(seconds as number)}
                      </div>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="text-muted">No data yet.</p>
              {/if}
            </div>

            <div
              class="bg-dark border border-primary rounded-xl p-6 flex flex-col"
            >
              <h3 class="text-xl font-semibold mb-4">Languages</h3>
              {#if langEntries.length > 0}
                <div class="space-y-3">
                  {#each langEntries as [label, seconds]}
                    <div class="flex items-center gap-3">
                      <div
                        class="w-1/3 truncate font-medium text-white"
                        title={label}
                      >
                        {label}
                      </div>
                      <div
                        class="flex-1 bg-darkless rounded h-3 overflow-hidden"
                      >
                        <div
                          class="h-3 bg-primary rounded"
                          style={`width:${percentOf(seconds as number, langMax)}%`}
                        ></div>
                      </div>
                      <div class="w-16 text-sm text-muted text-right">
                        {secondsToDisplay(seconds as number)}
                      </div>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="text-muted">No language data.</p>
              {/if}
            </div>

            <div
              class="bg-dark border border-primary rounded-xl p-6 flex flex-col"
            >
              <h3 class="text-xl font-semibold mb-4">Editors</h3>
              {#if editorEntries.length > 0}
                <div class="space-y-3">
                  {#each editorEntries as [label, seconds]}
                    <div class="flex items-center gap-3">
                      <div
                        class="w-1/3 truncate font-medium text-white"
                        title={label}
                      >
                        {label}
                      </div>
                      <div
                        class="flex-1 bg-darkless rounded h-3 overflow-hidden"
                      >
                        <div
                          class="h-3 bg-primary rounded"
                          style={`width:${percentOf(seconds as number, editorMax)}%`}
                        ></div>
                      </div>
                      <div class="w-16 text-sm text-muted text-right">
                        {secondsToDisplay(seconds as number)}
                      </div>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="text-muted">No editor data.</p>
              {/if}
            </div>

            <div
              class="bg-dark border border-primary rounded-xl p-6 flex flex-col"
            >
              <h3 class="text-xl font-semibold mb-4">Operating Systems</h3>
              {#if osEntries.length > 0}
                <div class="space-y-3">
                  {#each osEntries as [label, seconds]}
                    <div class="flex items-center gap-3">
                      <div
                        class="w-1/3 truncate font-medium text-white"
                        title={label}
                      >
                        {label}
                      </div>
                      <div
                        class="flex-1 bg-darkless rounded h-3 overflow-hidden"
                      >
                        <div
                          class="h-3 bg-primary rounded"
                          style={`width:${percentOf(seconds as number, osMax)}%`}
                        ></div>
                      </div>
                      <div class="w-16 text-sm text-muted text-right">
                        {secondsToDisplay(seconds as number)}
                      </div>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="text-muted">No OS data.</p>
              {/if}
            </div>

            <div
              class="bg-dark border border-primary rounded-xl p-6 flex flex-col md:col-span-2"
            >
              <h3 class="text-xl font-semibold mb-4">Project Timeline</h3>
              {#if timelineEntries.length > 0}
                <div class="flex flex-col gap-2 max-h-96 overflow-y-auto">
                  {#each timelineEntries as [week, stats]}
                    {@const total = Object.values(
                      stats as Record<string, number>,
                    ).reduce(
                      (a: number, v: any) => a + ((v as number) || 0),
                      0,
                    )}
                    <div class="flex items-center gap-3">
                      <div class="w-28 text-sm text-muted">{week}</div>
                      <div
                        class="flex-1 bg-darkless rounded h-3 overflow-hidden"
                      >
                        <div class="flex h-3 w-full">
                          {#each Object.entries(stats as Record<string, number>) as [project, seconds]}
                            <div
                              class="h-3 bg-primary/80"
                              style={`width:${percentOf(seconds as number, total)}%`}
                              title={`${project}: ${secondsToDisplay(seconds as number)}`}
                            ></div>
                          {/each}
                        </div>
                      </div>
                      <div class="w-16 text-sm text-muted text-right">
                        {secondsToDisplay(total)}
                      </div>
                    </div>
                  {/each}
                </div>
              {:else}
                <p class="text-muted">No timeline data.</p>
              {/if}
            </div>
          </div>
        </div>
      {/if}
    </Deferred>
  </div>

  <div id="activity_graph">
    <Deferred data="activity_graph_html">
      {#snippet fallback()}
        <div class="w-full overflow-x-auto mt-6 pb-2.5 animate-pulse">
          <div class="grid grid-rows-7 grid-flow-col gap-1 w-full lg:w-1/2">
            {#each activitySquares as _}
              <div class="w-3 h-3 rounded-sm bg-darkless opacity-50"></div>
            {/each}
          </div>
          <p class="super mt-2">
            <span class="h-3 w-48 bg-darkless rounded inline-block"></span>
          </p>
        </div>
      {/snippet}
      {@html activity_graph_html ?? ""}
    </Deferred>
  </div>
</div>
