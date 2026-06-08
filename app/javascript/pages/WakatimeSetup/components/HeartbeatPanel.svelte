<script lang="ts">
  import { onMount, untrack } from "svelte";
  import type { Snippet } from "svelte";
  import { apiV1MyHeartbeats } from "../../../api";

  interface Props {
    apiKey: string;
    waitingTitle: string;
    messages: string[];
    sourceType?: string;
    recentThresholdSeconds: number;
    success: Snippet<[{ timeAgo: string; editor: string }]>;
  }

  let {
    apiKey,
    waitingTitle,
    messages,
    sourceType,
    recentThresholdSeconds,
    success,
  }: Props = $props();

  const url = $derived(
    apiV1MyHeartbeats.mostRecent.path(
      sourceType ? { query: { source_type: sourceType } } : undefined,
    ),
  );

  let hasHeartbeat = $state(false);
  let timeAgo = $state("");
  let editor = $state("");
  let checkCount = $state(0);
  let statusMessage = $state(untrack(() => messages[0] ?? ""));
  let panelClass = $state("border-darkless");

  async function check() {
    try {
      const res = await fetch(url, {
        headers: { Authorization: `Bearer ${apiKey}` },
      });
      const data = await res.json();
      if (data.has_heartbeat) {
        const secondsAgo =
          (Date.now() - new Date(data.heartbeat.created_at).getTime()) / 1000;
        if (secondsAgo <= recentThresholdSeconds) {
          hasHeartbeat = true;
          timeAgo = data.time_ago;
          editor = data.editor;
          panelClass = "border-green bg-green/5";
          return;
        }
      }
      throw new Error("no heartbeat");
    } catch {
      checkCount++;
      if (checkCount % 3 === 0) {
        statusMessage = messages[Math.floor(checkCount / 3) % messages.length];
      }
    }
  }

  onMount(() => {
    check();
    const interval = setInterval(() => {
      if (!hasHeartbeat) check();
    }, 5000);
    return () => clearInterval(interval);
  });
</script>

<div
  class="border border-darkless rounded-xl p-6 bg-dark transition-all duration-300 {panelClass}"
>
  {#if !hasHeartbeat}
    <div class="flex flex-col items-center justify-center text-center py-2">
      <h4 class="text-lg font-semibold text-surface-content mb-1">
        {waitingTitle}
      </h4>
      <p class="text-sm text-secondary mb-4 max-w-sm">{statusMessage}</p>
    </div>
  {:else}
    {@render success({ timeAgo, editor })}
  {/if}
</div>
