<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { onMount } from "svelte";

  onMount(() => {
    const timeout = setTimeout(() => window.close(), 1000);
    return () => clearTimeout(timeout);
  });
</script>

<svelte:head><title>Successfully signed in!</title></svelte:head>
<p>Successfully signed in! You can close this window.</p>
