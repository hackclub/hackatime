<script lang="ts">
  import Button from "../../../components/Button.svelte";
  import { copyToClipboard } from "./copy";

  let { value, timeoutMs = 1500 }: { value: string; timeoutMs?: number } =
    $props();

  let copied = $state(false);

  const onCopy = async () => {
    if (!value) return;
    try {
      await copyToClipboard(value);
      copied = true;
      setTimeout(() => (copied = false), timeoutMs);
    } catch {
      copied = false;
    }
  };
</script>

<div class="flex flex-wrap items-center gap-2">
  <code
    class="min-w-0 flex-1 break-all rounded-md border border-surface-200 bg-darker px-3 py-2 font-mono text-xs text-surface-content"
  >
    {value}
  </code>
  <Button type="button" variant="surface" onclick={onCopy}>
    {copied ? "Copied" : "Copy"}
  </Button>
</div>
