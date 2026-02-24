<script lang="ts">
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";

  type HttpMethod = "post" | "delete" | "patch";

  let {
    open = $bindable(false),
    title,
    description,
    actionPath,
    confirmLabel,
    csrfToken,
    method = "post",
    confirmStyle = "primary",
  }: {
    open?: boolean;
    title: string;
    description: string;
    actionPath: string;
    confirmLabel: string;
    csrfToken: string;
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

      <form method="post" action={actionPath} class="m-0">
        {#if method !== "post"}
          <input type="hidden" name="_method" value={method} />
        {/if}
        <input type="hidden" name="authenticity_token" value={csrfToken} />

        <Button
          type="submit"
          variant={confirmStyle === "danger" ? "surface" : "primary"}
          class={`h-10 w-full ${confirmStyle === "danger" || isDelete ? "!border-red/45 !bg-red/15 !text-red hover:!bg-red/25" : "text-on-primary"}`}
        >
          {confirmLabel}
        </Button>
      </form>
    </div>
  {/snippet}
</Modal>
