<script lang="ts">
  import { Dialog } from "bits-ui";
  import type { Snippet } from "svelte";

  let {
    open = $bindable(false),
    title,
    description = "",
    maxWidth = "max-w-lg",
    bodyClass = "mb-6 rounded-xl border border-surface-200/60 bg-darker/30 p-4",
    onContentClick,
    hasIcon = false,
    hasBody = false,
    hasActions = false,
    icon,
    body,
    actions,
  }: {
    open?: boolean;
    title: string;
    description?: string;
    maxWidth?: string;
    bodyClass?: string;
    onContentClick?: (event: MouseEvent) => void;
    hasIcon?: boolean;
    hasBody?: boolean;
    hasActions?: boolean;
    icon?: Snippet;
    body?: Snippet;
    actions?: Snippet;
  } = $props();
</script>

<Dialog.Root bind:open>
  <Dialog.Portal>
    <Dialog.Overlay
      class="bits-modal-overlay fixed inset-0 z-9999 bg-darker/80 backdrop-blur-md"
    />

    <Dialog.Content
      class={`bits-modal-content fixed inset-0 z-10000 m-auto h-fit w-[calc(100vw-2rem)] ${maxWidth} overflow-hidden rounded-2xl border border-surface-300/70 bg-surface shadow-[0_28px_90px_rgba(0,0,0,0.5)] outline-none`}
      onclick={onContentClick}
    >
      <div
        class="absolute inset-x-0 top-0 h-1 bg-primary"
      ></div>

      <div class="p-6 sm:p-8">
        <div class="mb-5 flex items-start justify-between gap-4">
          <div class="min-w-0">
            {#if hasIcon}
              <div
                class="mb-3 inline-flex items-center justify-center rounded-xl border border-surface-200/70 bg-surface-100/50 p-2.5 text-primary"
              >
                {@render icon?.()}
              </div>
            {/if}

            <Dialog.Title
              class="text-balance text-2xl font-semibold tracking-tight text-surface-content"
            >
              {title}
            </Dialog.Title>

            {#if description}
              <Dialog.Description
                class="mt-2 text-sm leading-relaxed text-muted sm:text-[15px]"
              >
                {description}
              </Dialog.Description>
            {/if}
          </div>

          <Dialog.Close
            class="inline-flex h-12 w-12 items-center justify-center rounded-lg text-surface-content/75 outline-none transition-colors hover:bg-surface-100/60 hover:text-surface-content focus-visible:ring-2 focus-visible:ring-primary/70 focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
            aria-label="Close"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              class="h-6 w-6"
              aria-hidden="true"
            >
              <path d="M18 6L6 18" />
              <path d="M6 6l12 12" />
            </svg>
          </Dialog.Close>
        </div>

        {#if hasBody}
          <div class={bodyClass}>
            {@render body?.()}
          </div>
        {/if}

        {#if hasActions}
          <div>{@render actions?.()}</div>
        {/if}
      </div>
    </Dialog.Content>
  </Dialog.Portal>
</Dialog.Root>
