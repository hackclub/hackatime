<script module lang="ts">
  export type DestructiveAction = {
    title: string;
    description: string;
    actionPath: string;
    confirmLabel: string;
    method?: "post" | "delete" | "patch";
    confirmStyle?: "primary" | "danger";
  };
</script>

<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";

  let {
    action,
    onClose,
  }: {
    action: DestructiveAction | null;
    onClose: () => void;
  } = $props();
</script>

<Modal
  data={action}
  {onClose}
  title={action?.title ?? ""}
  description={action?.description}
  maxWidth="max-w-md"
  hasActions
>
  {#snippet actions({
    actionPath,
    confirmLabel,
    method = "post",
    confirmStyle = "primary",
  })}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={onClose}
      >
        Cancel
      </Button>

      <Form action={actionPath} {method} class="m-0" onSuccess={onClose}>
        <Button
          type="submit"
          variant={confirmStyle === "danger" ? "surface" : "primary"}
          class={`h-10 w-full ${confirmStyle === "danger" || method === "delete" ? "!border-red/45 !bg-red/15 !text-red hover:!bg-red/25" : "text-on-primary"}`}
        >
          {confirmLabel}
        </Button>
      </Form>
    </div>
  {/snippet}
</Modal>
