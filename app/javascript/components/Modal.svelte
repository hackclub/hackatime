<script lang="ts" generics="T = undefined">
  import { onMount } from "svelte";
  import type { Snippet } from "svelte";
  import type ModalInner from "./ModalInner.svelte";

  let {
    open = $bindable(false),
    data,
    onClose,
    title,
    description = "",
    maxWidth = "",
    bodyClass = "",
    onContentClick,
    hasBody = false,
    hasActions = false,
    body,
    actions,
  }: {
    /** Open state for modals whose content never changes. */
    open?: boolean;
    /**
     * Payload for modals that show per-open content, such as the item being
     * confirmed. The modal is open while `data` is not null, and `body` and
     * `actions` receive it. Reset it to null to close the modal.
     */
    data?: T | null;
    /** Called when the user dismisses the modal. */
    onClose?: () => void;
    title: string;
    description?: string;
    maxWidth?: string;
    bodyClass?: string;
    onContentClick?: (event: MouseEvent) => void;
    hasBody?: boolean;
    hasActions?: boolean;
    body?: Snippet<[T]>;
    actions?: Snippet<[T]>;
  } = $props();

  const isOpen = $derived(data === undefined ? open : data !== null);

  // The dialog stays on screen for its close animation. Keep showing what it
  // showed while open, so callers can reset its state as soon as it closes.
  let lastShown: { title: string; description: string; data: T } | undefined;
  const shown = $derived.by(() => {
    if (isOpen || !lastShown) {
      lastShown = { title, description, data: data as T };
    }
    return lastShown;
  });

  function onOpenChange(next: boolean) {
    open = next;
    if (!next) onClose?.();
  }

  let Inner = $state<typeof ModalInner | null>(null);

  function load() {
    if (Inner) return;
    import("./ModalInner.svelte").then((m) => {
      Inner = m.default;
    });
  }

  $effect(() => {
    if (isOpen) load();
  });

  onMount(() => {
    const w = window as unknown as {
      requestIdleCallback?: (
        cb: () => void,
        opts?: { timeout?: number },
      ) => void;
    };
    if (typeof w.requestIdleCallback === "function") {
      w.requestIdleCallback(load, { timeout: 3000 });
    } else {
      setTimeout(load, 500);
    }
  });
</script>

{#if Inner}
  <Inner
    open={isOpen}
    {onOpenChange}
    title={shown.title}
    description={shown.description}
    data={shown.data}
    {maxWidth}
    {bodyClass}
    {onContentClick}
    {hasBody}
    {hasActions}
    {body}
    {actions}
  />
{/if}
