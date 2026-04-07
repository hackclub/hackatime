<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../../../components/Button.svelte";
  import Modal from "../../../../components/Modal.svelte";

  let {
    open = $bindable(false),
    provider,
    description,
    unlinkPath,
  }: {
    open?: boolean;
    provider: string;
    description: string;
    unlinkPath: string;
  } = $props();
</script>

<Modal
  bind:open
  title={`Unlink ${provider} account?`}
  {description}
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={() => (open = false)}
      >
        Cancel
      </Button>
      <Form
        method="delete"
        action={unlinkPath}
        class="m-0"
        onSuccess={() => (open = false)}
      >
        {#snippet children({ processing })}
          <Button
            type="submit"
            variant="primary"
            class="h-10 w-full text-on-primary"
            disabled={processing}
          >
            Unlink {provider}
          </Button>
        {/snippet}
      </Form>
    </div>
  {/snippet}
</Modal>
