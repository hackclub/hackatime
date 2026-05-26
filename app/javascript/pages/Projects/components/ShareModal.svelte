<script lang="ts">
  import { router } from "@inertiajs/svelte";
  import Button from "../../../components/Button.svelte";
  import Modal from "../../../components/Modal.svelte";
  import { myProjectRepoMappings } from "../../../api";

  let {
    open = $bindable(false),
    projectName,
    isShared,
    shareUrl,
  }: {
    open: boolean;
    projectName: string;
    isShared: boolean;
    shareUrl?: string | null;
  } = $props();

  let copied = $state(false);
  let toggling = $state(false);

  const copyShareUrl = async () => {
    if (!shareUrl) return;
    try {
      await navigator.clipboard.writeText(shareUrl);
      copied = true;
      setTimeout(() => (copied = false), 2000);
    } catch {}
  };

  const toggleShare = () => {
    toggling = true;
    router.patch(
      myProjectRepoMappings.toggleShare.path({ projectName }),
      {},
      { preserveScroll: true, onFinish: () => (toggling = false) },
    );
  };
</script>

<Modal
  bind:open
  title="Share project"
  description={isShared
    ? "Anyone with the link can view this project's stats."
    : "Share a public link so anyone can view this project's stats."}
  maxWidth="max-w-sm"
  hasBody
  bodyClass="mb-4"
  hasActions
>
  {#snippet body()}
    {#if isShared && shareUrl}
      <div class="flex items-center gap-2">
        <input
          type="text"
          readonly
          value={shareUrl}
          class="flex-1 rounded-lg border border-surface-200 bg-input px-3 py-2 text-sm text-surface-content"
          onclick={(e) => e.currentTarget.select()}
        />
        <Button
          type="button"
          variant="primary"
          size="sm"
          onclick={copyShareUrl}
        >
          {copied ? "Copied!" : "Copy"}
        </Button>
      </div>
    {/if}
  {/snippet}

  {#snippet actions()}
    <Button
      type="button"
      variant={isShared ? "dark" : "primary"}
      class="w-full"
      disabled={toggling}
      onclick={toggleShare}
    >
      {isShared ? "Make private" : "Share project"}
    </Button>
  {/snippet}
</Modal>
