<script lang="ts">
  import { Form } from "@inertiajs/svelte";
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";

  type HttpMethod = "post" | "delete" | "patch";

  let {
    open = $bindable(false),
    title,
    description,
    actionPath,
    confirmLabel,
    method = "post",
    confirmStyle = "primary",
  }: {
    open?: boolean;
    title: string;
    description: string;
    actionPath: string;
    confirmLabel: string;
    method?: HttpMethod;
    confirmStyle?: "primary" | "danger";
  } = $props();

  const close = () => {
    open = false;
  };

  const isDelete = $derived(method === "delete");
</script>

<Modal bind:open {title} {description} maxWidth="max-w-md" hasActions>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted"
        onclick={close}
      >
        Cancel
      </Button>

      <Form action={actionPath} {method} class="m-0" onSuccess={close}>
        <Button
          type="submit"
          variant={confirmStyle === "danger" ? "surface" : "primary"}
          class={`h-10 w-full ${confirmStyle === "danger" || isDelete ? "!border-red/45 !bg-red/15 !text-red hover:!bg-red/25" : "text-on-primary"}`}
        >
          {confirmLabel}
        </Button>
      </Form>
    </div>
  {/snippet}
</Modal>
