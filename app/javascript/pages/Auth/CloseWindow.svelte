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
<main>
  <p>Successfully signed in! You can close this window.</p>
</main>

<style>
  main {
    position: fixed;
    inset: 0;
    z-index: 50;
    background: white;
    color: black;
    font-family: "Times New Roman", serif;
    font-size: medium;
    line-height: normal;
    margin: 0;
    padding: 8px;
  }

  p {
    margin: 0 0 1em;
  }
</style>
