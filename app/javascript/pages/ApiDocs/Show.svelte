<script module lang="ts">
  export const layout = false;
</script>

<script lang="ts">
  import { onMount } from "svelte";

  let { title, spec_url }: { title: string; spec_url: string } = $props();

  const configuration = $derived(
    JSON.stringify({
      theme: "purple",
      layout: "modern",
      hideDownloadButton: false,
      customCss:
        'a.no-underline.hover\\:underline[href="https://www.scalar.com"][target="_blank"] { display: none !important; }',
      metaData: { title, description: "The API for Hackatime" },
    }),
  );

  onMount(() => {
    const app = document.getElementById("app");
    app?.style.setProperty("display", "none");
    document.body.style.setProperty("display", "block");

    const reference = document.createElement("script");
    reference.id = "api-reference";
    reference.dataset.url = spec_url;
    reference.dataset.configuration = configuration;
    document.body.appendChild(reference);

    const loader = document.createElement("script");
    loader.src =
      "https://cdn.jsdelivr.net/npm/@scalar/api-reference@1.58.0/dist/browser/standalone.js";
    loader.integrity =
      "sha384-blqXcztiBhcKCu5cq4LLXtLyV3ASqFluFLJZuJjiDGKBweY6ZJGHJhqOK84toOji";
    loader.crossOrigin = "anonymous";
    document.body.appendChild(loader);

    return () => {
      loader.remove();
      reference.remove();
      app?.style.removeProperty("display");
      document.body.style.removeProperty("display");
    };
  });
</script>

<svelte:head><title>{title}</title></svelte:head>

<style>
  :global(body) {
    margin: 0;
  }
</style>
