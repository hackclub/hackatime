<script lang="ts">
  import type { MiniLeaderboardData } from "../../../types/index";

  let { data }: { data: MiniLeaderboardData } = $props();

  function rankDisplay(rank: number): string {
    switch (rank) {
      case 1:
        return "🥇";
      case 2:
        return "🥈";
      case 3:
        return "🥉";
      default:
        return String(rank);
    }
  }

  function streakColorClasses(count: number) {
    if (count >= 30) {
      return {
        bg: "from-blue-900/20 to-indigo-900/20",
        border: "border-blue-700",
        icon: "text-blue-400",
        text: "text-blue-300",
      };
    } else if (count >= 7) {
      return {
        bg: "from-red-900/20 to-orange-900/20",
        border: "border-red-700",
        icon: "text-red-400",
        text: "text-red-300",
      };
    } else {
      return {
        bg: "from-orange-900/20 to-yellow-900/20",
        border: "border-orange-700",
        icon: "text-orange-400",
        text: "text-orange-300",
      };
    }
  }
</script>

{#if data.entries.length > 0}
  <div class="bg-elevated rounded-xl border border-primary p-4 shadow-lg">
    <p class="text-xs italic text-muted mb-4">{data.subtitle}</p>
    <div class="space-y-2">
      {#each data.entries as entry}
        <div
          class="flex items-center p-3 rounded-lg bg-dark transition-colors duration-200 {entry.is_current_user
            ? 'border border-primary'
            : ''}"
        >
          <div class="w-8 text-center text-lg">{rankDisplay(entry.rank)}</div>
          <div class="flex-1 mx-3 min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <div class="user-info flex items-center gap-2">
                <img
                  src={entry.user.avatar_url}
                  alt="{entry.user.display_name}'s avatar"
                  class="w-8 h-8 rounded-full aspect-square border border-gray-300"
                />
                <a
                  href={entry.user.profile_path}
                  class="text-blue-500 hover:underline"
                >{entry.user.display_name}</a>
              </div>
              {#if entry.needs_github_link}
                <span class="text-xs italic text-muted">
                  <a
                    href={entry.settings_path}
                    target="_blank"
                    class="text-accent hover:text-cyan-400 transition-colors"
                    >Link active projects</a
                  >
                </span>
              {/if}
              {#if entry.active_project}
                <span class="text-xs italic text-muted">
                  working on
                  {#if entry.active_project.repo_url}
                    <a
                      href={entry.active_project.repo_url}
                      target="_blank"
                      class="text-accent hover:text-cyan-400 transition-colors"
                      >{entry.active_project.name}</a
                    >
                  {:else}
                    {entry.active_project.name}
                  {/if}
                </span>
              {/if}
              {#if entry.streak_count > 0}
                {@const colors = streakColorClasses(entry.streak_count)}
                <div
                  class="inline-flex items-center gap-1 px-2 py-1 bg-gradient-to-r {colors.bg} border {colors.border} rounded-lg"
                  title="{entry.streak_count > 30
                    ? '30+ daily streak'
                    : `${entry.streak_count} day streak`}"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    width="16"
                    height="16"
                    viewBox="0 0 24 24"
                    class="{colors.icon}"
                  >
                    <path
                      fill="currentColor"
                      d="M10 2c0-.88 1.056-1.331 1.692-.722c1.958 1.876 3.096 5.995 1.75 9.12l-.08.174l.012.003c.625.133 1.203-.43 2.303-2.173l.14-.224a1 1 0 0 1 1.582-.153C18.733 9.46 20 12.402 20 14.295C20 18.56 16.409 22 12 22s-8-3.44-8-7.706c0-2.252 1.022-4.716 2.632-6.301l.605-.589c.241-.236.434-.43.618-.624C9.285 5.268 10 3.856 10 2"
                    />
                  </svg>
                  <span class="text-md font-semibold {colors.text}">
                    {entry.streak_count > 30 ? "30+" : entry.streak_count}
                  </span>
                </div>
              {/if}
            </div>
          </div>
          <div class="shrink-0 font-mono text-sm text-white font-medium">
            {entry.total_display}
          </div>
        </div>
      {/each}
    </div>
    <div class="mt-4 text-right">
      <a
        href={data.full_leaderboard_path}
        class="text-sm text-secondary hover:text-cyan-400 transition-colors"
        >View full leaderboard</a
      >
    </div>
  </div>
{/if}
