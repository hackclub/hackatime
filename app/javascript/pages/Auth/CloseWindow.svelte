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

<style>
  :global(html),
  :global(body) {
    background: white;
    color: black;
    font-family: "Times New Roman", serif;
    font-size: medium;
    line-height: normal;
  }

  :global(body) {
    display: block;
    margin: 8px;
  }

  :global(#app) {
    display: contents;
    min-height: 0;
  }

  p {
    margin: 0 0 1em;
  }
</style>
