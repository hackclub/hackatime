<script lang="ts">
  import "@fontsource-variable/spline-sans";
  import "../app.css";

  let { children } = $props();
</script>

<svelte:head>
  <title>Hackatime</title>
  <meta
    name="description"
    content="Track coding time across your editors with an open source backend"
  />
</svelte:head>

<header class="site-header">
  <a class="brand" href="/">Hackatime</a>
  <nav aria-label="Primary">
    <a href="/profiles/testuser">Profile</a>
    <a href="/setup">Setup</a>
    <a href="http://localhost:3002/api-docs">API</a>
  </nav>
</header>

<main>{@render children()}</main>

<footer>
  <p>Open source coding time for everyone</p>
</footer>
