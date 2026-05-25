<script lang="ts">
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

  $effect(() => {
    if (!open || Inner) return;
    import("./ModalInner.svelte").then((m) => {
      Inner = m.default;
    });
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
