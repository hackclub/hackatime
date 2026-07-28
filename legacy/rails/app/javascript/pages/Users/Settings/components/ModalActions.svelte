<script lang="ts">
  import type { Snippet } from "svelte";
  import Button from "../../../../components/Button.svelte";

  let {
    onCancel,
    cancelLabel = "Cancel",
    confirm,
  }: {
    onCancel: () => void;
    cancelLabel?: string;
    confirm: Snippet;
  } = $props();
</script>

<div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
  <Button
    type="button"
    variant="dark"
    class="h-10 w-full border border-surface-300 text-muted"
    onclick={onCancel}
  >
    {cancelLabel}
  </Button>
  {@render confirm()}
</div>
