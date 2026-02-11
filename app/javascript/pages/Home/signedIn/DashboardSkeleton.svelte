<script lang="ts">
  const filterRows = Array.from({ length: 6 });
  const statCards = Array.from({ length: 6 });
</script>

<div class="flex flex-col gap-6 w-full animate-pulse">
  <!-- Filter skeletons -->
  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-2">
    {#each filterRows as _}
      <div class="flex-1 min-w-37.5 min-h-10 relative">
        <div class="h-3 w-16 bg-darkless rounded mb-1.5"></div>
        <div class="h-10 w-full bg-darkless rounded-lg"></div>
      </div>
    {/each}
  </div>

  <!-- Stat card skeletons -->
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
    {#each statCards as _, i}
      <div
        class={`flex flex-col justify-between p-4 pb-6 rounded-xl border h-full min-h-23.5 ${
          i === 0
            ? "bg-primary/10 border-primary/30"
            : "bg-white/5 border-white/10"
        }`}
      >
        <div class="h-3 w-16 bg-darkless rounded mb-2"></div>
        <div class="h-5 w-24 bg-darkless rounded"></div>
      </div>
    {/each}
  </div>

  <!-- Chart area skeletons -->
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 w-full">
    <div class="h-48 bg-darkless/50 rounded-xl"></div>
    <div class="h-48 bg-darkless/50 rounded-xl"></div>
    <div class="h-48 bg-darkless/50 rounded-xl"></div>
    <div class="h-48 bg-darkless/50 rounded-xl"></div>
    <div class="lg:col-span-2 h-48 bg-darkless/50 rounded-xl"></div>
  </div>
</div>
