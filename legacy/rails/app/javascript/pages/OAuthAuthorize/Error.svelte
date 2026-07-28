<script module>
  export const layout = false;
</script>

<script lang="ts">
  import Button from "../../components/Button.svelte";
  import CenteredCard from "./components/CenteredCard.svelte";

  let {
    page_title,
    error_description,
  }: { page_title: string; error_description: string } = $props();
</script>

<svelte:head>
  <title>{page_title}</title>
</svelte:head>

<CenteredCard
  tone="red"
  iconPath="M12 9v3.75m-9.303 3.376c-.866 1.5.217 3.374 1.948 3.374h14.71c1.73 0 2.813-1.874 1.948-3.374L13.949 3.378c-.866-1.5-3.032-1.5-3.898 0L2.697 16.126zM12 15.75h.007v.008H12v-.008z"
  title={page_title}
>
  <div
    class="rounded-xl border border-red/20 bg-red/5 p-5 text-center text-sm text-red/90"
  >
    {error_description}
  </div>

  <div class="mt-5 text-center">
    <Button href="/" variant="surface">Return home</Button>
  </div>
</CenteredCard>
