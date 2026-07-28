<script lang="ts">
  import { onMount } from "svelte";
  import ApiKeyForm from "$lib/components/ApiKeyForm.svelte";
  import StatCard from "$lib/components/StatCard.svelte";
  import { api, authorized } from "$lib/api/client";
  import { duration } from "$lib/format";

  type Me = {
    id: number;
    emails: string[];
    slack_id: string | null;
    github_username: string | null;
    trust_factor: { trust_level: string; trust_value: number };
  };

  let apiKey = $state("");
  let loading = $state(false);
  let error = $state("");
  let me = $state<Me | null>(null);
  let totalSeconds = $state(0);
  let projects = $state<string[]>([]);

  onMount(() => {
    apiKey = localStorage.getItem("hackatime-api-key") ?? "";
    if (apiKey) void loadDashboard();
  });

  async function loadDashboard() {
    loading = true;
    error = "";
    const headers = authorized(apiKey);
    const [meResult, statsResult, projectsResult] = await Promise.all([
      api.GET("/api/v1/authenticated/me", { headers }),
      api.GET("/api/v1/users/{username}/stats", {
        params: {
          path: { username: "my" },
          query: { total_seconds: true },
        },
        headers,
      }),
      api.GET("/api/v1/users/{username}/projects", {
        params: { path: { username: "my" } },
        headers,
      }),
    ]);

    if (meResult.error || statsResult.error || projectsResult.error) {
      error = "That API key could not load the dashboard";
      loading = false;
      return;
    }

    localStorage.setItem("hackatime-api-key", apiKey);
    me = meResult.data as Me;
    totalSeconds = Number(
      (statsResult.data as unknown as { total_seconds?: number })
        .total_seconds ?? 0,
    );
    projects = (projectsResult.data as { projects: string[] }).projects;
    loading = false;
  }

  function signOut() {
    localStorage.removeItem("hackatime-api-key");
    apiKey = "";
    me = null;
    totalSeconds = 0;
    projects = [];
  }
</script>

<section class="hero">
  <div class="eyebrow">Your time belongs to you</div>
  <h1>See where your coding time goes</h1>
  <p>
    Hackatime collects heartbeats from your editor and turns them into clear,
    private and portable activity data.
  </p>
</section>

{#if me}
  <section class="dashboard panel">
    <div class="section-heading">
      <div>
        <p class="eyebrow">Dashboard</p>
        <h2>Welcome back</h2>
      </div>
      <button class="button quiet" type="button" onclick={signOut}
        >Forget key</button
      >
    </div>

    <div class="stats-grid">
      <StatCard
        label="Tracked time"
        value={duration(totalSeconds)}
        detail="All time"
      />
      <StatCard
        label="Projects"
        value={String(projects.length)}
        detail="Active projects"
      />
      <StatCard
        label="Trust"
        value={me.trust_factor.trust_level}
        detail="Public trust level"
      />
    </div>

    <div class="project-list">
      <h3>Projects</h3>
      {#if projects.length}
        <div class="chips">
          {#each projects as project}<span>{project}</span>{/each}
        </div>
      {:else}
        <p>No heartbeats yet. Follow setup to send your first one.</p>
      {/if}
    </div>
  </section>
{:else}
  <section class="auth panel">
    <div>
      <p class="eyebrow">Try the dashboard</p>
      <h2>Connect with an API key</h2>
      <p>
        The key stays in this browser and is sent only to your Hackatime API.
      </p>
    </div>
    <ApiKeyForm bind:value={apiKey} {loading} onsubmit={loadDashboard} />
    {#if error}<p class="error" role="alert">{error}</p>{/if}
  </section>
{/if}

<section class="feature-grid">
  <article>
    <span>01</span>
    <h2>Fast ingestion</h2>
    <p>Rust accepts editor heartbeats with a small memory footprint.</p>
  </article>
  <article>
    <span>02</span>
    <h2>Exact analytics</h2>
    <p>
      ClickHouse keeps full timestamps in a compact user and time ordered table.
    </p>
  </article>
  <article>
    <span>03</span>
    <h2>Typed end to end</h2>
    <p>OpenAPI generates the client used by this SvelteKit frontend.</p>
  </article>
</section>
