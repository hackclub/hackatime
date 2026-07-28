<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";
  import CenteredCard from "./components/CenteredCard.svelte";

  let { page_title, code }: { page_title: string; code: string } = $props();

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

<CenteredCard
  tone="green"
  iconPath="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
  title={page_title}
  description="Copy this code and paste it into your application to complete authorization."
>
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
</CenteredCard>
