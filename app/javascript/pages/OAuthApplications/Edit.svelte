<script lang="ts">
  import Form from "./Form.svelte";
  import type { OAuthApplicationFormProps } from "./types";

  let props: OAuthApplicationFormProps = $props();
</script>

<svelte:head>
  <title>{props.page_title}</title>
</svelte:head>

<div class="mx-auto max-w-4xl space-y-4">
  <header>
    <h1 class="text-3xl font-bold text-surface-content">{props.heading}</h1>
    <p class="mt-1 text-sm text-muted">{props.subheading}</p>
  </header>

  <Form {...props} />
</div>
