<script lang="ts">
  let {
    label,
    state,
    inProgress,
    errorMessage,
    completedSummary,
    bgClass = "bg-darker",
  }: {
    label: string;
    state: string;
    inProgress: boolean;
    errorMessage?: string | null;
    completedSummary?: string | null;
    bgClass?: string;
  } = $props();

  const stateColor = $derived(
    state === "failed"
      ? "text-red-300"
      : state === "completed"
        ? bgClass === "bg-surface"
          ? "text-green-300"
          : "text-primary"
        : "text-muted",
  );

  function prettyStatus(s: string): string {
    switch (s) {
      case "queued":
        return "Queued…";
      case "requesting_dump":
        return "Requesting heartbeats…";
      case "waiting_for_dump":
        return "Waiting for heartbeats…";
      case "downloading_dump":
        return "Downloading heartbeats…";
      case "importing":
        return "Importing heartbeats…";
      case "completed":
        return "Done!";
      case "failed":
        return "Failed";
      default:
        return s;
    }
  }
</script>

<div
  class={`flex flex-wrap items-center gap-2 rounded-md border border-surface-200 ${bgClass} px-3 py-2 text-sm`}
>
  {#if inProgress}
    <svg
      class="h-4 w-4 shrink-0 animate-spin text-primary"
      viewBox="0 0 24 24"
      fill="none"
    >
      <circle
        cx="12"
        cy="12"
        r="10"
        stroke="currentColor"
        stroke-width="3"
        class="opacity-25"
      />
      <path
        d="M4 12a8 8 0 018-8"
        stroke="currentColor"
        stroke-width="3"
        stroke-linecap="round"
      />
    </svg>
  {/if}
  <span class="text-surface-content">{label}</span>
  <span class="text-muted">·</span>
  <span class={stateColor}>{prettyStatus(state)}</span>
  {#if errorMessage}
    <span class="text-red-300">{errorMessage}</span>
  {/if}
  {#if state === "completed" && completedSummary}
    <span class="tabular-nums text-muted">{completedSummary}</span>
  {/if}
</div>
