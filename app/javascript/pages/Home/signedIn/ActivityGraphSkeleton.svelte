<script lang="ts">
  const squares = Array.from({ length: 365 });
</script>

<div class="w-full overflow-x-auto mt-6 pb-2.5 animate-pulse">
  <div class="grid grid-rows-7 grid-flow-col gap-1 w-full lg:w-1/2">
    {#each squares as _}
      <div class="w-3 h-3 rounded-sm bg-darkless opacity-50"></div>
    {/each}
  </div>
  <p class="super mt-2">
    <span class="h-3 w-48 bg-darkless rounded inline-block"></span>
  </p>
</div>
