<script lang="ts">
  import { onMount } from "svelte";
  import type { Component, Snippet } from "svelte";

  let {
    open = $bindable(false),
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
    open?: boolean;
    title: string;
    description?: string;
    maxWidth?: string;
    bodyClass?: string;
    onContentClick?: (event: MouseEvent) => void;
    hasBody?: boolean;
    hasActions?: boolean;
    body?: Snippet;
    actions?: Snippet;
  } = $props();

  type InnerProps = {
    open?: boolean;
    title: string;
    description?: string;
    maxWidth?: string;
    bodyClass?: string;
    onContentClick?: (event: MouseEvent) => void;
    hasBody?: boolean;
    hasActions?: boolean;
    body?: Snippet;
    actions?: Snippet;
  };

  let Inner = $state<Component<InnerProps> | null>(null);

  function load() {
    if (Inner) return;
    import("./ModalInner.svelte").then((m) => {
      Inner = m.default;
    });
  }

  $effect(() => {
    if (open) load();
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
    bind:open
    {title}
    {description}
    {maxWidth}
    {bodyClass}
    {onContentClick}
    {hasBody}
    {hasActions}
    {body}
    {actions}
  />
{/if}
