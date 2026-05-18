<script lang="ts">
  import { Dialog } from "bits-ui";
  import type { Snippet } from "svelte";

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

  // Lazily mount the bits-ui Dialog tree. bits-ui Dialog (including Floating UI
  // setup, portal allocation, etc.) is the hot spot during Inertia SPA
  // navigations where every page that imports Modal pays the mount cost
  // up-front. Once a modal has been opened we keep it mounted so close
  // animations still play.
  let hasEverOpened = $state(open);
  $effect(() => {
    if (open) hasEverOpened = true;
  });
</script>

{#if hasEverOpened}
  <Dialog.Root bind:open>
    <Dialog.Portal>
      <Dialog.Overlay
        class="bits-modal-overlay fixed inset-0 z-9999 bg-darker/80 backdrop-blur-md"
      />

      <Dialog.Content
        class={`bits-modal-content fixed inset-0 z-10000 m-auto h-fit w-[calc(100%-2rem)] ${maxWidth} overflow-hidden rounded-2xl border border-surface-300/70 bg-surface shadow-[0_28px_90px_rgba(0,0,0,0.5)] outline-none`}
        onclick={onContentClick}
      >
        <div class="h-1 w-full bg-primary"></div>
        <div class="p-4 sm:p-6">
          <div class="mb-5 flex items-start justify-between gap-4">
            <div class="min-w-0">
              <Dialog.Title
                class="text-balance text-base md:text-lg font-semibold tracking-tight text-surface-content"
              >
                {title}
              </Dialog.Title>

              {#if description}
                <Dialog.Description
                  class="mt-1 text-sm leading-snug text-muted sm:text-[15px]"
                >
                  {description}
                </Dialog.Description>
              {/if}
            </div>

            <Dialog.Close
              class="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-lg text-surface-content/75 outline-none transition-colors hover:bg-surface-100/60 hover:text-surface-content focus-visible:ring-2 focus-visible:ring-primary/70 focus-visible:ring-offset-2 focus-visible:ring-offset-surface"
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
                class="h-5 w-5"
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
{/if}

<style>
  /* shadcn-ui dialog animations: 200ms duration, ease-out, fade + zoom 95% */
  :global(.bits-modal-overlay[data-state="open"]) {
    animation: shadcn-fade-in 200ms cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(.bits-modal-overlay[data-state="closed"]) {
    animation: shadcn-fade-out 200ms cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(.bits-modal-content[data-state="open"]) {
    animation:
      shadcn-fade-in 200ms cubic-bezier(0.4, 0, 0.2, 1),
      shadcn-zoom-in 200ms cubic-bezier(0.4, 0, 0.2, 1);
  }
  :global(.bits-modal-content[data-state="closed"]) {
    animation:
      shadcn-fade-out 200ms cubic-bezier(0.4, 0, 0.2, 1),
      shadcn-zoom-out 200ms cubic-bezier(0.4, 0, 0.2, 1);
  }

  @keyframes shadcn-fade-in {
    from {
      opacity: 0;
    }
    to {
      opacity: 1;
    }
  }
  @keyframes shadcn-fade-out {
    from {
      opacity: 1;
    }
    to {
      opacity: 0;
    }
  }
  @keyframes shadcn-zoom-in {
    from {
      transform: scale(0.95);
    }
    to {
      transform: scale(1);
    }
  }
  @keyframes shadcn-zoom-out {
    from {
      transform: scale(1);
    }
    to {
      transform: scale(0.95);
    }
  }
</style>
