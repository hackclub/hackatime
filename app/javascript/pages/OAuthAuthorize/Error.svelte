<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";

  interface Props {
    page_title: string;
    error_description: string;
  }

  let { page_title, error_description }: Props = $props();
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<div class="flex min-h-screen w-screen items-center justify-center p-4">
  <div class="w-full max-w-md">
    <div class="mb-6 text-center">
      <div
        class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-red/10 text-red"
      >
        <svg
          class="h-8 w-8"
          fill="none"
          stroke="currentColor"
          stroke-width="1.5"
          viewBox="0 0 24 24"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
          />
        </svg>
      </div>
      <h1 class="text-2xl font-bold text-surface-content">{page_title}</h1>
    </div>

    <div
      class="rounded-xl border border-red/20 bg-red/5 p-5 text-center text-sm text-red/90"
    >
      {error_description}
    </div>

    <div class="mt-5 text-center">
      <Button href="/" variant="surface">Return home</Button>
    </div>
  </div>
</div>
