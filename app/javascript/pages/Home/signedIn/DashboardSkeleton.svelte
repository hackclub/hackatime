<script lang="ts">
  const six = Array.from({ length: 6 });
</script>

<div class="flex flex-col gap-6 w-full animate-pulse">
  <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-6 gap-3 mb-2">
    {#each six as _}
      <div class="flex-1 min-w-37.5 min-h-10">
        <div class="h-3 w-16 bg-darkless rounded mb-1.5"></div>
        <div class="h-10 w-full bg-darkless rounded-lg"></div>
      </div>
    {/each}
  </div>
  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
    {#each six as _, i}
      <div
        class="flex flex-col justify-between p-4 pb-6 rounded-xl border h-full min-h-23.5 {i ===
        0
          ? 'bg-primary/10 border-primary/30'
          : 'bg-surface-100/30 border-surface-200'}"
      >
        <div class="h-3 w-16 bg-darkless rounded mb-2"></div>
        <div class="h-5 w-24 bg-darkless rounded"></div>
      </div>
    {/each}
  </div>
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 w-full">
    {#each Array.from({ length: 4 }) as _}
      <div class="h-48 bg-darkless/50 rounded-xl"></div>
    {/each}
    <div class="lg:col-span-2 h-48 bg-darkless/50 rounded-xl"></div>
  </div>
</div>
