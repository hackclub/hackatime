<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { Link } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import { staticPages } from "../../api";

  let {
    status_code,
    title,
    message,
    sentry_event_id,
  }: {
    status_code: number;
    title: string;
    message: string;
    sentry_event_id: string | null;
  } = $props();
</script>

<svelte:head>
  <title>{title} - Hackatime</title>
  <meta name="robots" content="noindex, nofollow" />
</svelte:head>

<div
  class="flex min-h-screen w-full items-center justify-center bg-surface mx-auto"
>
  <div
    class="flex max-w-3xl flex-col items-center justify-center p-8 text-center"
  >
    <div class="mb-6">
      <div class="mb-2 text-8xl font-bold text-primary">{status_code}</div>
      <h1 class="mb-4 text-3xl font-bold text-surface-content">{title}</h1>
    </div>
    <div class="mb-6 rounded-xl border border-darkless bg-dark p-6">
      <p class="text-lg text-muted">{message}</p>
    </div>
    <div class="flex flex-col gap-4 sm:flex-row">
      <Link
        href={staticPages.index.path()}
        class="rounded-lg bg-primary px-6 py-3 font-medium text-on-primary transition-colors hover:bg-primary/75"
        >Go Home</Link
      >
      <Button
        type="button"
        variant="dark"
        class="px-6 py-3"
        onclick={() => history.back()}>Go Back</Button
      >
    </div>
    <p class="mt-8 text-sm text-muted">
      If this problem persists, please contact us on
      <a
        href="https://hackclub.slack.com"
        class="text-primary hover:underline"
        target="_blank"
        rel="noreferrer">Slack</a
      >.
    </p>
    {#if sentry_event_id}
      <div class="mt-4 rounded-lg border border-dark bg-darkless p-3">
        <p class="text-xs text-muted">
          Error ID: <code class="select-all text-primary"
            >{sentry_event_id}</code
          >
        </p>
      </div>
    {/if}
  </div>
</div>
