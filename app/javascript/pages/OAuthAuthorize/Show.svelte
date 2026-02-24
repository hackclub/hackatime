<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";

  interface Props {
    page_title: string;
    code: string;
  }

  let { page_title, code }: Props = $props();

  let copied = $state(false);

  const copyCode = async () => {
    try {
      await navigator.clipboard.writeText(code);
      copied = true;
      setTimeout(() => (copied = false), 2000);
    } catch {
      copied = false;
    }
  };
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="flex min-h-screen w-screen items-center justify-center p-4">
  <div class="w-full max-w-md">
    <div class="mb-6 text-center">
      <div
        class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-green/10 text-green"
      >
        <svg
          class="h-8 w-8"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
          />
        </svg>
      </div>
      <h1 class="text-2xl font-bold text-surface-content">{page_title}</h1>
      <p class="mt-2 text-sm text-muted">
        Copy this code and paste it into your application to complete
        authorization.
      </p>
    </div>

    <div class="rounded-xl border border-surface-200 bg-dark p-5">
      <p class="mb-2 text-xs font-medium uppercase tracking-wider text-muted">
        Authorization code
      </p>
      <div class="flex items-center gap-2">
        <code
          class="min-w-0 flex-1 break-all rounded-lg border border-surface-200 bg-darker px-3 py-2.5 font-mono text-xs text-surface-content"
        >
          {code}
        </code>
        <Button type="button" variant="surface" onclick={copyCode}>
          {copied ? "Copied!" : "Copy"}
        </Button>
      </div>
    </div>
  </div>
</div>
