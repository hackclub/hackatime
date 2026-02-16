<script lang="ts">
  import Modal from "./Modal.svelte";
  import { onMount } from "svelte";

  // `Modal` is the shared visual shell for every modal in the app.
  // `RailsModal` stays as a thin adapter for server-rendered Rails views:
  // - pulls HTML fragments from the host element dataset/templates
  // - listens for legacy `modal:open` / `modal:close` DOM events
  // - closes when Rails action markup marks elements with `data-modal-close='true'`

  let {
    modalId,
    title,
    description = "",
    iconHtml = "",
    customHtml = "",
    actionsHtml = "",
    maxWidth = "max-w-md",
  }: {
    modalId: string;
    title: string;
    description?: string;
    iconHtml?: string;
    customHtml?: string;
    actionsHtml?: string;
    maxWidth?: string;
  } = $props();

  let open = $state(false);

  const handleActionClick = (event: MouseEvent) => {
    const target = event.target as HTMLElement | null;
    if (!target) return;
    if (target.closest("[data-modal-close='true']")) {
      open = false;
    }
  };

  onMount(() => {
    const host = document.getElementById(modalId);
    if (!host) return;

    const onOpen = () => (open = true);
    const onClose = () => (open = false);

    host.addEventListener("modal:open", onOpen as EventListener);
    host.addEventListener("modal:close", onClose as EventListener);

    return () => {
      host.removeEventListener("modal:open", onOpen as EventListener);
      host.removeEventListener("modal:close", onClose as EventListener);
    };
  });
</script>

<Modal
  bind:open
  {title}
  {description}
  {maxWidth}
  onContentClick={handleActionClick}
  hasIcon={Boolean(iconHtml)}
  hasBody={Boolean(customHtml)}
  hasActions={Boolean(actionsHtml)}
>
  {#snippet icon()}
    {@html iconHtml}
  {/snippet}

  {#snippet body()}
    {@html customHtml}
  {/snippet}

  {#snippet actions()}
    {@html actionsHtml}
  {/snippet}
</Modal>
