<script lang="ts">
  import plur from "plur";
  import type { LayoutProps } from "../../types";
  import { sessions } from "../../api";

  let {
    footer,
    showStopImpersonating,
  }: {
    footer: LayoutProps["footer"];
    showStopImpersonating: boolean;
  } = $props();

  const stopImpersonatingPath = sessions.stopImpersonating.path();

  const latinPhrases = [
    "carpe diem",
    "nemo sine vitio est",
    "docendo discimus",
    "per aspera ad astra",
    "ex nihilo nihil",
    "aut viam inveniam aut faciam",
    "semper ad mellora",
    "soli fortes, una fortiores",
    "nulla tenaci invia est via",
    "nihil boni sine labore",
  ];

  const graphTitle = (hourIndex: number, users: number) => {
    const hoursAgo = hourIndex + 1;
    const phrase = latinPhrases[(hoursAgo + users) % latinPhrases.length];
    return `${hoursAgo} ${plur("hour", hoursAgo)} ago, ${users} ${plur("person", users)} logged time. '${phrase}.'`;
  };

  const statsText = $derived(
    `${footer.heartbeat_recent_count} ${plur("heartbeat", footer.heartbeat_recent_count)} (${footer.heartbeat_recent_imported_count} imported) in the past 24 hours. (DB: ${footer.query_count} ${plur("query", footer.query_count)}, ${footer.query_cache_count} cached) (CACHE: ${footer.cache_hits} hits, ${footer.cache_misses} misses) (${footer.requests_per_second})`,
  );
</script>

<footer
  class="relative w-full mt-12 mb-5 p-2.5 text-center text-xs text-text-muted"
>
  <div class="container mx-auto">
    <p class="brightness-60 hover:brightness-100 transition-all duration-200">
      Using Inertia. Build <a
        href={footer.commit_link}
        class="text-inherit underline opacity-80 hover:opacity-100 transition-opacity duration-200"
        >{footer.git_version}</a
      >
      from {footer.server_start_time_ago} ago. {statsText}
    </p>
    {#if showStopImpersonating}
      <a
        href={stopImpersonatingPath}
        data-turbo-prefetch="false"
        class="text-primary font-bold hover:text-red transition-colors duration-200"
        >Stop impersonating</a
      >
    {/if}
  </div>
  <div class="flex flex-row gap-2 mt-4 justify-center">
    {#each footer.active_users_graph as hour, i}
      <div
        class="bg-white opacity-10 grow max-w-1 rounded-sm"
        title={graphTitle(i, hour.users)}
        style={`height: ${hour.height}px`}
      ></div>
    {/each}
  </div>
</footer>
