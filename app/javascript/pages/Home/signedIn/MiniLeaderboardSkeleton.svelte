<script lang="ts">
  const rows = Array.from({ length: 6 });
</script>

<div class="bg-elevated rounded-xl border border-primary p-4 shadow-lg">
  <p class="text-xs italic text-muted mb-4">
    This leaderboard shows time logged in the last 24 hours (UTC time).
  </p>
  <div class="space-y-2">
    {#each rows as _}
      <div class="flex items-center p-3 rounded-lg bg-dark animate-pulse">
        <div class="w-8 text-center">
          <div class="h-5 w-5 bg-darkless rounded mx-auto"></div>
        </div>
        <div class="flex-1 mx-3 min-w-0">
          <div class="flex items-center gap-2">
            <div class="w-8 h-8 bg-darkless rounded-full shrink-0"></div>
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
