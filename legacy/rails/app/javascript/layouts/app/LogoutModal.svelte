<script lang="ts">
  import Button from "../../components/Button.svelte";
  import Modal from "../../components/Modal.svelte";
  import { sessions } from "../../api";

  let {
    open = $bindable(false),
    csrfToken,
  }: {
    open?: boolean;
    csrfToken: string;
  } = $props();

  const signoutPath = sessions.destroy.path();
</script>

<Modal
  bind:open
  title="Woah, hold on a sec!"
  description="You sure you want to log out? You can sign back in later but that is a bit of a hassle..."
  maxWidth="max-w-lg"
  hasActions
>
  {#snippet actions()}
    <div class="grid grid-cols-1 gap-3 sm:grid-cols-2">
      <Button
        type="button"
        onclick={() => (open = false)}
        variant="dark"
        class="h-10 w-full border border-surface-300 text-muted">Go back</Button
      >

      <form method="post" action={signoutPath} class="m-0">
        <input type="hidden" name="authenticity_token" value={csrfToken} />
        <input type="hidden" name="_method" value="delete" />
        <Button
          type="submit"
          variant="primary"
          class="h-10 w-full text-on-primary">Log out now</Button
        >
      </form>
    </div>
  {/snippet}
</Modal>
