<script lang="ts">
  import { sessions } from "../../../api";
  import GithubFill from "hcicons-svelte/github-fill";
</script>

<div class="bg-dark border border-primary/40 rounded-xl p-4 md:p-5 mb-4">
  <div
    class="flex flex-col gap-3 md:flex-row md:items-center md:justify-between"
  >
    <div class="flex items-center gap-3 min-w-0">
      <GithubFill size={24} class="text-surface-content shrink-0" />
      <span class="text-surface-content"
        >Link your GitHub account to unlock project linking, show what you're
        working on, and qualify for leaderboards!</span
      >
    </div>
    <a
      href={sessions.githubNew.path()}
      class="bg-primary hover:opacity-90 text-on-primary font-medium px-4 py-2 rounded-lg transition-colors duration-200 shrink-0 text-center w-full md:w-fit"
      data-turbo="false">Connect GitHub</a
    >
  </div>
</div>
