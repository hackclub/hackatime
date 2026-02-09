<script lang="ts">
  const filterRows = Array.from({ length: 6 });
</script>

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
